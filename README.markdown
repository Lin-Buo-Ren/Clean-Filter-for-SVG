# 用於 SVG 的清潔過濾器<br>Clean Filter for SVG
[![Build Status of the latest development snapshot on Travis CI](https://travis-ci.org/Lin-Buo-Ren/Clean-Filter-for-SVG.svg?branch=master)](https://travis-ci.org/Lin-Buo-Ren/Clean-Filter-for-SVG)[![Snap Status](https://build.snapcraft.io/badge/Lin-Buo-Ren/Clean-Filter-for-SVG.svg)](https://build.snapcraft.io/user/Lin-Buo-Ren/Clean-Filter-for-SVG)  
A clean filter for SVG for Git and other applications.  Currently it strips out personal information and metadata not suited for version controlling.

<https://github.com/Lin-Buo-Ren/Clean-Filter-for-SVG>

## 原作者<br>Original Author
林博仁

## 如何使用<br>How to use?
The following instructions is for projects that're using Git as their VCS to integrate Clean Filter for SVG, you may use this software for other purposes as well.

## If your system supports [Snapd](https://snapcraft.io/docs/installing-snapd)
1. Install Snapd if you haven't, make sure to restart your login session to make the environment changes take effect
1. Install [the clean-filter-for-svg snap](https://snapcraft.io/clean-filter-for-svg)  

    [![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/clean-filter-for-svg)[![安裝軟體敬請移駕 Snap Store](https://snapcraft.io/static/images/badges/tw/snap-store-black.svg)](https://snapcraft.io/clean-filter-for-svg)

1. Merge the following gitattributes(5) file setup:  

    ```
	# gitattributes - defining attributes per path
	# https://git-scm.com/docs/gitattributes
	## Setup filters for SVG
	## Refer .gitconfig for more information
	*.svg filter=svg
    ```

1. Merge the following git-config(1) configuration:

    ```
	# Project-specific Git Configuration
	# Documentation: manpage: git-config(1)
	[filter "svg"]
		clean = "clean-filter-for-svg"

    ```

1. Profit!  The SVG files checked into the staging area will now passed through the clean filter, you may want to implement a development environment setup script like [this](<Setup Development Environment.bash>) to ease other contributer's setup.

## If your system doesn't support Snapd
1. Install [XMLStarlet Command Line XML Toolkit](http://xmlstar.sourceforge.net), which is this software's runtime dependency.  Make sure the `xmlstarlet` command is in your command search `PATH`s
1. Clone this Git repository as your repo's submodule
1. Merge the following gitattributes(5) file setup:  

    ```
	# gitattributes - defining attributes per path
	# https://git-scm.com/docs/gitattributes
	## Setup filters for SVG
	## Refer .gitconfig for more information
	*.svg filter=svg
    ```

1. Merge the following git-config(1) configuration:

    ```
	# Project-specific Git Configuration
	# Documentation: manpage: git-config(1)
	[filter "svg"]
		clean = "\"./path/to/the/submodule/Clean Filter for SVG.bash\""

    ```

1. Profit!  The SVG files checked into the staging area will now pass through the clean filter, you may want to implement a development environment setup script like [this](<Setup Development Environment.bash>) to ease other contributer's setup.

## Known alternatives
* [cdcasey/svgclean](https://github.com/cdcasey/svgclean)

## 智慧財產授權條款<br>Intellectual Property License
GNU GPLv3 or any later releases you prefer

```
這個專案介紹文件是基於專案介紹文件範本
This README is based on Project README Template

http://github.com/Lin-Buo-Ren/Project-README-templates
```
