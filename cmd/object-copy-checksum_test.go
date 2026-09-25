// Copyright (c) 2015-2026 MinIO, Inc.
//
// This file is part of MinIO Object Storage stack
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

package cmd

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/minio/minio/internal/auth"
	xhttp "github.com/minio/minio/internal/http"
)

// The PutObject and CopyObject request helpers the SSE-C tests share,
// from pgsty/silo cmd/object-copy-checksum_test.go (c0e71597). This fork
// does not carry the CopyObject checksum change that file tests; the SSE-C
// advisory fixes it does carry use these two helpers.

// putCopyChecksumSource stores data under bucket/object through the API
// router with a SigV4-signed PutObject and fails the test on any status
// but 200.
func putCopyChecksumSource(t *testing.T, apiRouter http.Handler, credentials auth.Credentials,
	bucket, object string, data []byte, headers map[string]string,
) {
	t.Helper()
	req, err := newTestSignedRequestV4(http.MethodPut, getPutObjectURL("", bucket, object),
		int64(len(data)), bytes.NewReader(data), credentials.AccessKey, credentials.SecretKey, headers)
	if err != nil {
		t.Fatalf("failed to build PutObject request: %v", err)
	}
	rec := httptest.NewRecorder()
	apiRouter.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("PutObject(%s) failed: %d %s", object, rec.Code, rec.Body.String())
	}
}

// copyChecksumRequest sends a SigV4-signed CopyObject of bucket/source to
// bucket/destination and returns the recorded response.
func copyChecksumRequest(t *testing.T, apiRouter http.Handler, credentials auth.Credentials,
	bucket, source, destination string, headers map[string]string,
) *httptest.ResponseRecorder {
	t.Helper()
	req, err := newTestSignedRequestV4(http.MethodPut, getCopyObjectURL("", bucket, destination),
		0, nil, credentials.AccessKey, credentials.SecretKey, headers)
	if err != nil {
		t.Fatalf("failed to build CopyObject request: %v", err)
	}
	req.Header.Set(xhttp.AmzCopySource, SlashSeparator+pathJoin(bucket, source))
	// Re-sign so x-amz-copy-source is covered by the signature, as real S3
	// clients send it.
	if credentials.AccessKey != "" && credentials.SecretKey != "" {
		if err := signRequestV4(req, credentials.AccessKey, credentials.SecretKey); err != nil {
			t.Fatalf("failed to re-sign CopyObject request: %v", err)
		}
	}
	rec := httptest.NewRecorder()
	apiRouter.ServeHTTP(rec, req)
	return rec
}
