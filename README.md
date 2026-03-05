<img align="left" style="width:240px" src="logo/odx.png" width="288px">

<br>

**A build tool for [Odin](https://odin-lang.org/).** <br>
Odx is a build tool/system for the Odin programming language. <br>
It handles building, running, testing and caching for Odin projects.

*NOTE: This is an unofficial project & it is being actively developed, meaning some things could be changed in future versions.*

---
<br clear="left">

[![Made with Odin](https://img.shields.io/badge/made%20with-Odin-blue)](https://odin-lang.org/)
[![GitHub Releases Downloads](https://img.shields.io/github/downloads/FinochioM/ODx/total)](https://github.com/FinochioM/ODx/releases)
[![GitHub Stars](https://img.shields.io/github/stars/FinochioM/ODx?style=flat&label=stars)](https://github.com/FinochioM/ODx/stargazers)
[![GitHub commits since tagged version](https://img.shields.io/github/commits-since/FinochioM/ODx/latest)](https://github.com/FinochioM/ODx/commits/master)
[![License](https://img.shields.io/badge/license-zlib-blue)](LICENSE)
[![Latest Stable Release](https://img.shields.io/github/v/release/FinochioM/ODx?label=latest%20stable)](https://github.com/FinochioM/ODx/releases/latest)

[![Build Windows](https://github.com/FinochioM/ODx/actions/workflows/build_windows.yml/badge.svg)](https://github.com/FinochioM/ODx/actions/workflows/build_windows.yml)
[![Build Linux](https://github.com/FinochioM/ODx/actions/workflows/build_linux.yml/badge.svg)](https://github.com/FinochioM/ODx/actions/workflows/build_linux.yml)
[![Build macOS](https://github.com/FinochioM/ODx/actions/workflows/build_macos.yml/badge.svg)](https://github.com/FinochioM/ODx/actions/workflows/build_macos.yml)

## Installation 

**Prebuilt binary**

You can download one of the auto-generated binaries from [Releases](https://github.com/FinochioM/ODx/releases) and put it somewhere on your `PATH`.

**Build from source**

You can also just build from source, which is better in my opinion.

It requires odin to be installed.

```sh
git clone https://github.com/FinochioM/odx
cd odx
odin build src -collection:src=src -out:build/odx
```

## Wiki
todo

## Roadmap
Future changes or bug fixes will be added [here](roadmap.md).

## License
ODx is licensed under the zlib license. Read the [LICENSE](LICENSE) for more information.