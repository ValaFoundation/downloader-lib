# vala-downloader-lib

A small Vala library for downloading files with optional speed limiting.

## Quick init (dependency setup)

To add `vala-downloader-lib` as a Meson subproject dependency, run:

```sh
./init.sh
```

Or run it directly from GitHub:

```sh
curl -sSfL https://raw.githubusercontent.com/JanGalek/vala-downloader-lib/refs/heads/master/init.sh -o init.sh && chmod +x init.sh && ./init.sh && rm init.sh
```

## Features

- Synchronous and asynchronous download methods
- Optional speed limits in B/s, KB/s, MB/s, or GB/s
- Structured download result object with status and metrics
- Built on top of GLib/GIO and libsoup 3

## Public API (summary)

Namespace: `Downloader`

- `Manager`
  - `download(string url, string dest_path) -> Result`
  - `download_async(string url, string dest_path) -> Result`
  - `set_speed_limit_in_bytes(int64)`
  - `set_speed_limit_in_kilobytes(int64)`
  - `set_speed_limit_in_megabytes(int64)`
  - `set_speed_limit_in_gigabytes(int64)`
- `Result`
  - `is_downloaded` (`bool`)
  - `actual_speed_bps` (`int64`)
  - `remaining_time` (`int64`, seconds, `-1` when unknown)
  - `status_code` (`uint`, HTTP status)
	- `get_remaining_time_in_seconds() -> int64`
	- `get_remaining_time_in_minutes() -> int64`
	- `get_remaining_time_in_hours() -> int64`
	- `get_remaining_time_in_days() -> int64`
	- `get_actual_speed_in_kilobytes() -> int64`
	- `get_actual_speed_in_megabytes() -> int64`
	- `get_actual_speed_in_gigabytes() -> int64`

## Example: synchronous download

```vala
using Downloader;

int main (string[] args) {
	var manager = new Manager ();
	manager.set_speed_limit_in_megabytes (2);

	try {
		var result = manager.download (
			"https://example.com/file.zip",
			"/tmp/file.zip"
		);

		stdout.printf ("Downloaded: %s\n", result.is_downloaded ? "yes" : "no");
		stdout.printf ("HTTP status: %u\n", result.status_code);
		stdout.printf ("Actual speed: %" + int64.FORMAT + " B/s\n", result.actual_speed_bps);
		stdout.printf ("Actual speed: %" + int64.FORMAT + " KB/s\n", result.get_actual_speed_in_kilobytes ());
		stdout.printf ("Remaining time: %" + int64.FORMAT + " s\n", result.remaining_time);
		stdout.printf ("Remaining time: %" + int64.FORMAT + " min\n", result.get_remaining_time_in_minutes ());
	} catch (Error e) {
		stderr.printf ("Download failed: %s\n", e.message);
		return 1;
	}

	return 0;
}
```

## Example: asynchronous download

```vala
using Downloader;

public async int run_async () {
	var manager = new Manager ();
	manager.set_speed_limit_in_kilobytes (512);

	try {
		var result = yield manager.download_async (
			"https://example.com/file.iso",
			"/tmp/file.iso"
		);

		if (!result.is_downloaded) {
			stderr.printf ("HTTP error: %u\n", result.status_code);
			return 2;
		}

		stdout.printf ("Downloaded successfully at %" + int64.FORMAT + " B/s\n", result.actual_speed_bps);
		stdout.printf ("~ %" + int64.FORMAT + " MB/s\n", result.get_actual_speed_in_megabytes ());
		return 0;
	} catch (Error e) {
		stderr.printf ("Async download failed: %s\n", e.message);
		return 1;
	}
}
```

## Build

```sh
meson setup builddir
meson compile -C builddir
```

## Test

```sh
meson test -C builddir
```

or via Makefile helper:

```sh
make tests
```

## Dependencies

- glib-2.0
- gio-2.0
- libsoup-3.0
- gee-0.8

In consumer projects, use:

```meson
vala_downloader_dep = dependency('vala_downloader', fallback: ['vala-downloader-lib', 'vala_downloader_dep'])
```

Then add `vala_downloader_dep` to your target dependencies.

## License

MIT (see `LICENSE`).
