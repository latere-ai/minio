// Copyright (c) 2026 PGSTY
// SPDX-License-Identifier: AGPL-3.0-only

package cmd

import (
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/minio/minio/internal/auth"
	xhttp "github.com/minio/minio/internal/http"
)

// The presigned-request helpers the SN-2026-012 payload-hash test uses,
// from pgsty/silo cmd/signature-v4-boundary_test.go (87d8b596). This fork
// does not carry that commit's signature and policy condition changes or
// the tests of them; only these two helpers.

// presignBoundaryRequest presigns r at date, signing exactly the given
// headers.
func presignBoundaryRequest(t *testing.T, r *http.Request, date time.Time, signedHeaders []string, cred auth.Credentials) {
	t.Helper()
	query := r.URL.Query()
	query.Del(xhttp.AmzSignature)
	query.Set(xhttp.AmzAlgorithm, signV4Algorithm)
	query.Set(xhttp.AmzDate, date.Format(iso8601Format))
	query.Set(xhttp.AmzExpires, "3600")
	query.Set(xhttp.AmzSignedHeaders, strings.Join(signedHeaders, ";"))
	query.Set(xhttp.AmzCredential, cred.AccessKey+"/"+getScope(date, globalSite.Region()))
	r.Form = query
	headers, code := extractSignedHeaders(signedHeaders, r)
	if code != ErrNone {
		t.Fatal(niceError(code))
	}
	canonical := getCanonicalRequest(headers, getContentSha256Cksum(r, serviceS3), query.Encode(), r.URL.Path, r.Method)
	key := getSigningKey(cred.SecretKey, date, globalSite.Region(), serviceS3)
	query.Set(xhttp.AmzSignature, getSignature(key, getStringToSign(canonical, date, getScope(date, globalSite.Region()))))
	r.URL.RawQuery = query.Encode()
	r.Form = query
}

// setupSignatureBoundaryTest initializes an FS object layer and the server
// configuration the signature verifiers read, and removes both at cleanup.
func setupSignatureBoundaryTest(t *testing.T) {
	t.Helper()
	obj, fsDir, err := prepareFS(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(fsDir) })
	if err = newTestConfig(globalMinioDefaultRegion, obj); err != nil {
		t.Fatal(err)
	}
}
