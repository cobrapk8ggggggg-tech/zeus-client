// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

enum AppUrls {
  // Zeus Manhwa (this fork) — update checks target our releases; on a private
  // repo the API 404s and the guarded update check silently finds nothing.
  zeusGithubUrl(url: "https://github.com/cobrapk8ggggggg-tech/zeus-client"),
  zeusLatestReleaseUrl(
      url: "https://github.com/cobrapk8ggggggg-tech/zeus-client/releases/latest"),
  zeusWhatsNew(
      url: "https://github.com/cobrapk8ggggggg-tech/zeus-client/releases/tag/"),
  zeusLatestReleaseApiUrl(
    url:
        "https://api.github.com/repos/cobrapk8ggggggg-tech/zeus-client/releases/latest",
  ),

  // Upstream credits (MPL-2.0 provenance)
  suwayomiGithubUrl(url: "https://github.com/Suwayomi/Tachidesk-Sorayomi"),
  suwayomiServerHelp(url: "https://github.com/Suwayomi/suwayomi-Server/wiki"),
  tachideskReddit(url: "https://www.reddit.com/r/Tachidesk"),
  flareSolverr(
      url:
          "https://github.com/FlareSolverr/FlareSolverr?tab=readme-ov-file#installation");

  const AppUrls({required this.url});

  final String url;
}
