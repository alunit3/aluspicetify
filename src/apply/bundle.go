package apply

import (
	"os"
	"strings"
)

// BundledCustomApps is the set of CustomApps shipped natively with
// this all-in-one fork. They are force-injected at runtime so the
// user gets a working storefront out-of-the-box, even when the
// config file is empty or explicitly cleared.
var BundledCustomApps = []string{
	"marketplace",
}

// BundledExtensions is the set of Extensions shipped natively with
// this all-in-one fork. They are force-injected at runtime so the
// user gets ad-blocking and the accompanying rxri utilities
// out-of-the-box, even when the config file is empty or cleared.
var BundledExtensions = []string{
	"adblock.js",
	"phraseToPlaylist.js",
	"songstats.js",
	"wikify.js",
	"writeify.js",
	"formatColors.js",
	"featureshuffle.js",
}

// bundleEnvVar is the environment variable used as an escape hatch
// for power users who want to disable the all-in-one native bundle
// entirely. When unset (or any value other than truthy) the bundle
// stays active by design, so a clean config still produces a fully
// customized client.
const bundleEnvVar = "SPICETIFY_DISABLE_BUNDLE"

// BundleDisabled reports whether the user has explicitly opted out
// of the all-in-one bundled modules via the SPICETIFY_DISABLE_BUNDLE
// environment variable.
func BundleDisabled() bool {
	v := strings.ToLower(strings.TrimSpace(os.Getenv(bundleEnvVar)))
	switch v {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}

// MergeBundled merges a user-provided list of items with a bundled
// list, de-duplicating case-insensitively so that pre-existing user
// entries are preserved and prioritized (user items first, followed
// by any missing bundled items). When the bundle is disabled, the
// user list is returned unchanged.
//
// This realizes the "implicit hardcoded injection" strategy: the
// bundled modules load even if the user clears their config, while
// custom user entries are never lost and never duplicated.
func MergeBundled(userItems, bundledItems []string) []string {
	if BundleDisabled() {
		return userItems
	}

	seen := make(map[string]bool, len(userItems)+len(bundledItems))
	merged := make([]string, 0, len(userItems)+len(bundledItems))

	for _, item := range userItems {
		key := strings.ToLower(strings.TrimSpace(item))
		if key == "" || seen[key] {
			continue
		}
		seen[key] = true
		merged = append(merged, item)
	}

	for _, item := range bundledItems {
		key := strings.ToLower(strings.TrimSpace(item))
		if key == "" || seen[key] {
			continue
		}
		seen[key] = true
		merged = append(merged, item)
	}

	return merged
}
