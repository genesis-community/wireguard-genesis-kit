package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("WireGuard Kit", func() {

	Describe("standalone", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "base-all-params",
			CloudConfig: "aws",
			CPI:         "aws",
		})

		// Vault fixture pre-seeds alice and bob in the peer registry —
		// the blueprint enumerates them into peers.dynamic.yml.
		Test(Environment{
			Name:        "peers",
			CloudConfig: "aws",
			CPI:         "aws",
		})

		Test(Environment{
			Name:        "azure",
			CloudConfig: "azure",
			CPI:         "azure",
		})

		Test(Environment{
			Name:        "stackit",
			CloudConfig: "stackit",
			CPI:         "stackit",
		})
	})

	Describe("ocfp", func() {
		Test(Environment{
			Name:        "ocfp-mgmt",
			CloudConfig: "aws-ocfp",
			CPI:         "aws",
		})
	})
})
