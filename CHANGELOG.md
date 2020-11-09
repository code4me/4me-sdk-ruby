# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2020-11-14

### Added

- This release contains a breaking change with regards to how to upload
  attachments. See paragraph "Attachments" in the README.md file for details.

### Changed

### Removed

- Option `attachments_exception` has been removed. An error in attachment
  upload will always result in a `Sdk4me::UploadFailed` error being raised.
- Attachments can no longer be provided via the `attachments` field.
- Inline images can no longer be referred to using `[attachment:<filepath>]`
  in rich text fields.

### Fixed


## [1.2.0] - 2020-09-28
### Deprecated
- Use of `api_token` is deprecated, switch to using `access_token` instead. -- https://developer.4me.com/v1/#authentication