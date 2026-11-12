# Plex DV for macOS

An experimental patch for the purple/green picture when Plex for Mac directly plays certain Dolby Vision Profile 5 videos. It builds a separate **Plex DV.app** using a modified libmpv renderer; it does not transcode the video on your Plex server. You keep your original Plex app and library.

**Status:** Confirmed to remove the purple tint on one Profile 5 movie on an M2 Max MacBook Pro, macOS 15.5, Plex for Mac 1.109.0. Other movies, displays, audio formats, versions and Macs have not been comprehensively tested. Colour accuracy, HDR output and Dolby Vision metadata passthrough have not been verified. This is an unofficial experiment, not a Plex product.

## Install

You need an Apple Silicon Mac, the Xcode command-line tools, Git, Homebrew and a working Plex for Mac app. Building requires several Homebrew packages. Review the install list first: Homebrew may also install or upgrade dependencies.

```sh
xcode-select --install # only if you don't have the command-line tools
brew install meson ninja pkgconf ffmpeg libplacebo libass vulkan-loader vulkan-headers molten-vk
```

Clone this repository and build a separate app:

```sh
git clone https://github.com/ac1dburnz/plex-dolby-vision-macos.git
cd plex-dolby-vision-macos
./install.sh /Applications/Plex.app
```

If Plex is in Downloads instead, use `./install.sh "$HOME/Downloads/Plex.app"`. The output is `~/Applications/Plex DV.app`. The installer refuses to overwrite an existing destination; you can pass a second argument to choose a different `.app` path. Quit other Plex windows, then open **Plex DV** and test a video. It uses the same Plex profile and preferences as the original app.

The build fetches a pinned mpv fork, compiles a replacement library and a small OpenGL interposer, copies Plex, and ad-hoc signs the copy. Build dependencies are dynamically linked from Homebrew: removing or upgrading them may stop the app working. Updating Plex DV itself may overwrite the patch; rebuild a new copy after updating the original. Since this re-signs a modified copy, macOS may ask you to confirm opening it.

## Revert

Quit Plex DV and open your original Plex app. To remove the patch, delete `~/Applications/Plex DV.app`. The installer does not modify the original app, Plex server, media files or Plex's `mpv.conf`. It installs build dependencies only if you choose to run the Homebrew command above; uninstalling the app does not remove those packages.

## How it works

Plex embeds libmpv using the OpenGL render API. The stock embedded renderer does not provide mpv's `gpu-next` pipeline. We build [posilash's mpv fork](https://github.com/posilash/mpv) at commit `2297e443d8e104ee3e1f4dac61431969dca0eb40`, and make its gpu-next OpenGL backend accept Plex's existing render API name. The small interposer requests an OpenGL core context for Plex's video view only; changing every Qt context can cause a black window or crash. This depends on internal Plex symbol names and is likely to require updates when Plex changes.

`src/plex-opengl.patch` contains the mpv change, `src/force-gl.c` contains the context interposer, and `src/render-test.c` is an isolated OpenGL initialization test. The mpv-derived patch is GPL-2.0-or-later; see [LICENSE](LICENSE) and [MPV-COPYRIGHT](MPV-COPYRIGHT).
