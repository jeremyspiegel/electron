// Copyright (c) 2013 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/common/crash_reporter/crash_reporter_mac.h"

#include <algorithm>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "base/mac/bundle_locations.h"
#include "base/mac/mac_util.h"
#include "base/memory/singleton.h"
#include "crashpad/client/crashpad_client.h"
#include "crashpad/client/crashpad_info.h"

namespace crash_reporter {

CrashReporterMac::CrashReporterMac() {}

CrashReporterMac::~CrashReporterMac() {}

void CrashReporterMac::InitBreakpad(const std::string& product_name,
                                    const std::string& version,
                                    const std::string& company_name,
                                    const std::string& submit_url,
                                    const base::FilePath& crashes_dir,
                                    bool upload_to_server,
                                    bool skip_system_crash_handler) {
  // check whether crashpad has been initialized.
  // Only need to initialize once.
  if (simple_string_dictionary_)
    return;

  if (is_browser_) {
    @autoreleasepool {
      base::FilePath framework_bundle_path = base::mac::FrameworkBundlePath();
      base::FilePath handler_path =
          framework_bundle_path.Append("Resources").Append("crashpad_handler");

      std::vector<std::string> args = {
          "--no-rate-limit",
          "--no-upload-gzip",  // not all servers accept gzip
      };

      crashpad::CrashpadClient crashpad_client;
      crashpad_client.StartHandler(handler_path, crashes_dir, crashes_dir,
                                   submit_url, StringMap(), args, true, false);
    }  // @autoreleasepool
  }

  crashpad::CrashpadInfo* crashpad_info =
      crashpad::CrashpadInfo::GetCrashpadInfo();
  if (skip_system_crash_handler) {
    crashpad_info->set_system_crash_reporter_forwarding(
        crashpad::TriState::kDisabled);
  }

  simple_string_dictionary_.reset(new crashpad::SimpleStringDictionary());
  crashpad_info->set_simple_annotations(simple_string_dictionary_.get());

  SetInitialCrashKeyValues(version);
  if (is_browser_) {
    database_ = crashpad::CrashReportDatabase::Initialize(crashes_dir);
    SetUploadToServer(upload_to_server);
  }
}

void CrashReporterMac::SetUploadParameters() {
  upload_parameters_["platform"] = "darwin";
}

// static
CrashReporterMac* CrashReporterMac::GetInstance() {
  return base::Singleton<CrashReporterMac>::get();
}

// static
CrashReporter* CrashReporter::GetInstance() {
  return CrashReporterMac::GetInstance();
}

}  // namespace crash_reporter
