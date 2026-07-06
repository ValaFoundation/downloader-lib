lib_sources = files('vala-library-template.vala')

vala_testcases_dep = dependency('vala_testcases', fallback: ['vala_testcases', 'vala_testcases_dep'])

vala_lib_deps = [
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('libsoup-3.0'),
  dependency('gee-0.8'),
  vala_testcases_dep
]

vala_lib = shared_library(
  'vala-downloader-lib',
  lib_sources,
  dependencies: vala_lib_deps,
  install: true,
  vala_vapi: 'vala-downloader-lib.vapi',
  vala_header: 'vala-downloader-lib.h'
)

vala_lib_dep = declare_dependency(
  link_with: vala_lib,
  include_directories: include_directories('.'),
  sources: lib_sources
)

pkg = import('pkgconfig')
pkg.generate(
  vala_lib,
  version: '1.0',
  name: 'vala-downloader-lib',
  filebase: 'vala-downloader-lib',
  description: 'Vala Library Template.'
)
