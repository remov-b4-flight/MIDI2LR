#ifndef MIDI2LR_DEBUGINFO_H
#define MIDI2LR_DEBUGINFO_H
/*
 * This file is part of MIDI2LR. Copyright (C) 2015 by Rory Jaffe.
 *
 * MIDI2LR is free software: you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with MIDI2LR.  If not,
 * see <http://www.gnu.org/licenses/>.
 *
 */
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "Misc.h"

class DebugInfo {
 public:
   explicit DebugInfo(std::string_view profile_directory) noexcept;

   [[nodiscard]] const std::vector<std::string>& GetInfo() const noexcept { return info_; }

 private:
   void LogAndSave(std::string&& msg)
   {
      rsj::Log(msg, std::source_location::current());
      info_.push_back(std::move(msg));
   }

   std::vector<std::string> info_;
};

#endif
