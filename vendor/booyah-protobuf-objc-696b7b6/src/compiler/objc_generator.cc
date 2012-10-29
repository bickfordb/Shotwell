// Protocol Buffers for Objective C
//
// Copyright 2010 Booyah Inc.
// Copyright 2008 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "objc_generator.h"

#include <google/protobuf/io/printer.h>
#include <google/protobuf/io/zero_copy_stream.h>
#include <google/protobuf/descriptor.pb.h>
#include <google/protobuf/stubs/strutil.h>

#include "objc_file.h"
#include "objc_helpers.h"

namespace google { namespace protobuf { namespace compiler { namespace objectivec {
  ObjectiveCGenerator::ObjectiveCGenerator() {
  }


  ObjectiveCGenerator::~ObjectiveCGenerator() {
  }


  bool ObjectiveCGenerator::Generate(const FileDescriptor* file,
    const string& parameter,
    OutputDirectory* output_directory,
    string* error) const {
      vector<pair<string, string> > options;
      ParseGeneratorParameter(parameter, &options);

      string output_list_file;

      for (int i = 0; i < options.size(); i++) {
        if (options[i].first == "output_list_file") {
          output_list_file = options[i].second;
        } else {
          *error = "Unknown generator option: " + options[i].first;
          return false;
        }
      }

      FileGenerator file_generator(file);

      string filepath = FilePath(file);

      // Generate header.
      {
        scoped_ptr<io::ZeroCopyOutputStream> output(
          output_directory->Open(filepath + ".pb.h"));
        io::Printer printer(output.get(), '$');
        file_generator.GenerateHeader(&printer);
      }

      // Generate m file.
      {
        scoped_ptr<io::ZeroCopyOutputStream> output(
          output_directory->Open(filepath + ".pb.m"));
        io::Printer printer(output.get(), '$');
        file_generator.GenerateSource(&printer);
      }

      return true;
  }

}  // namespace objectivec
}  // namespace compiler
}  // namespace protobuf
}  // namespace google
