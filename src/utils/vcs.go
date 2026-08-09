package utils

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
)

type GithubRelease struct {
	TagName string `json:"tag_name"`
	Message string `json:"message"`
}

// LatestReleaseRepo is the GitHub repo whose releases are checked
// against for update notifications and self-update. This fork ships
// its own release cadence (versions like "2.44.0-aio.1"), so it must
// track its own repo rather than upstream spicetify/cli.
const LatestReleaseRepo = "alunit3/aluspicetify"

func FetchLatestTag() (string, error) {
	res, err := http.Get("https://api.github.com/repos/" + LatestReleaseRepo + "/releases/latest")
	if err != nil {
		return "", err
	}

	body, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}

	var release GithubRelease
	if err = json.Unmarshal(body, &release); err != nil {
		return "", err
	}

	if release.TagName == "" {
		return "", errors.New("GitHub response: " + release.Message)
	}

	return release.TagName[1:], nil
}
