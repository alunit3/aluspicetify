package apply

import (
	"testing"
)

func TestMergeBundled(t *testing.T) {
	cases := []struct {
		name        string
		userItems   []string
		bundledItems []string
		disableEnv  string
		want        []string
	}{
		{
			name:         "empty user adds all bundled",
			userItems:    nil,
			bundledItems: []string{"adblock.js", "marketplace"},
			want:         []string{"adblock.js", "marketplace"},
		},
		{
			name:         "user items preserved and prioritized",
			userItems:    []string{"foo.js", "bar.js"},
			bundledItems: []string{"adblock.js"},
			want:         []string{"foo.js", "bar.js", "adblock.js"},
		},
		{
			name:         "duplicate bundled entry not re-added",
			userItems:    []string{"adblock.js", "foo.js"},
			bundledItems: []string{"adblock.js", "bar.js"},
			want:         []string{"adblock.js", "foo.js", "bar.js"},
		},
		{
			name:         "case-insensitive dedup",
			userItems:    []string{"Adblock.js"},
			bundledItems: []string{"adblock.js"},
			want:         []string{"Adblock.js"},
		},
		{
			name:         "blank entries skipped",
			userItems:    []string{"", "  ", "foo.js"},
			bundledItems: []string{"", "bar.js"},
			want:         []string{"foo.js", "bar.js"},
		},
		{
			name:         "bundle disabled returns user only",
			userItems:    []string{"foo.js"},
			bundledItems: []string{"adblock.js", "marketplace"},
			disableEnv:   "1",
			want:         []string{"foo.js"},
		},
		{
			name:         "bundle disabled with empty user returns empty",
			userItems:    nil,
			bundledItems: []string{"adblock.js"},
			disableEnv:   "true",
			want:         nil,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if tc.disableEnv != "" {
				t.Setenv(bundleEnvVar, tc.disableEnv)
			} else {
				t.Setenv(bundleEnvVar, "")
			}

			got := MergeBundled(tc.userItems, tc.bundledItems)

			if len(got) != len(tc.want) {
				t.Fatalf("len mismatch: got %v, want %v", got, tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("index %d: got %q, want %q (all: got=%v want=%v)", i, got[i], tc.want[i], got, tc.want)
				}
			}
		})
	}
}

func TestBundleDisabled(t *testing.T) {
	t.Setenv(bundleEnvVar, "")
	if BundleDisabled() {
		t.Fatal("expected disabled=false when env unset")
	}

	for _, val := range []string{"1", "true", "TRUE", "yes", "On"} {
		t.Setenv(bundleEnvVar, val)
		if !BundleDisabled() {
			t.Fatalf("expected disabled=true for env %q", val)
		}
	}

	for _, val := range []string{"0", "false", "no", "", "random"} {
		t.Setenv(bundleEnvVar, val)
		if BundleDisabled() {
			t.Fatalf("expected disabled=false for env %q", val)
		}
	}
}
