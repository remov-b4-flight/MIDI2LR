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
#include "CommandMenu.h"

#include <exception>

#include <gsl/gsl>

#include "CCoptions.h"
#include "Misc.h"
#include "PWoptions.h"
#include "Profile.h"

CommandMenu::CommandMenu(rsj::MidiMessageId message, const CommandSet& command_set,
    Profile& profile)

try : TextButtonAligned{CommandSet::UnassignedTranslated()}, command_set_(command_set),
    profile_(profile), message_{message} {
}

catch (const std::exception& e) {
   MIDI2LR_E_RESPONSE;
   throw;
}

void CommandMenu::ShowCCDialog() const
{
   CCoptions ccopt;
   ccopt.BindToControl(message_.channel - 1, message_.control_number); // convert 1-based to 0-based
   juce::DialogWindow::showModalDialog(juce::translate("Adjust CC dialog"), &ccopt, nullptr,
       juce::Colours::white, true);
}

void CommandMenu::ShowPWDialog() const
{
   PWoptions pwopt;
   pwopt.BindToControl(message_.channel - 1); // convert 1-based to 0-based
   juce::DialogWindow::showModalDialog(juce::translate("Adjust PW dialog"), &pwopt, nullptr,
       juce::Colours::white, true);
}

void CommandMenu::ShowDialogBasedOnMessageType() const
{
   switch (message_.msg_id_type) {
   case rsj::MessageType::kCc:
      ShowCCDialog();
      break;
   case rsj::MessageType::kPw:
      ShowPWDialog();
      break;
   case rsj::MessageType::kChanPressure:
   case rsj::MessageType::kKeyPressure:
   case rsj::MessageType::kNoteOff:
   case rsj::MessageType::kNoteOn:
   case rsj::MessageType::kPgmChange:
   case rsj::MessageType::kSystem:
      break; // do nothing for other types of controllers
   }
}

void CommandMenu::AddSubMenuItems(juce::PopupMenu& sub_menu, const juce::String& command,
   size_t index, bool& ticked) const
{
   if (profile_.CommandHasAssociatedMessage(command_set_.CommandAbbrevAt(index - 1))) {
      if (index == selected_item_) {
         ticked = true;
         sub_menu.addColouredItem(gsl::narrow_cast<int>(index), command, juce::Colours::red, true,
             true);
      }
      else {
         sub_menu.addColouredItem(gsl::narrow_cast<int>(index), command, juce::Colours::red, true,
             false);
      }
   }
   else {
      sub_menu.addItem(gsl::narrow_cast<int>(index), command, true, false);
   }
}

void CommandMenu::ProcessUserSelection(juce::PopupMenu& main_menu)
{
   if (auto result {gsl::narrow_cast<size_t>(main_menu.show())}) {
      if (result - 1 < command_set_.CommandAbbrevSize()) {
         profile_.InsertOrAssign(result - 1, message_);
         juce::Button::setButtonText(command_set_.CommandLabelAt(result - 1));
      }
      else {
         profile_.InsertOrAssign(0, message_);
         juce::Button::setButtonText(command_set_.CommandLabelAt(0));
         result = 0;
      }
      selected_item_ = result;
      // Map the selected command to the CC
   }
}

void CommandMenu::AddSubMenusToMainMenu(juce::PopupMenu& main_menu, size_t& index) const
{
   size_t submenu_number {0}; // to track name for submenu
   for (const auto& submenus : command_set_.GetMenuEntries()) {
      juce::PopupMenu sub_menu;
      auto ticked {false};
      for (const auto& command : submenus) {
         AddSubMenuItems(sub_menu, command, index, ticked);
         index++;
      }
      main_menu.addSubMenu(command_set_.GetMenus().at(submenu_number++), sub_menu, true, nullptr,
          ticked);
   }
}

void CommandMenu::ProcessMenuItems()
{
   size_t index {1};
   juce::PopupMenu main_menu;
   main_menu.addItem(gsl::narrow_cast<int>(index), CommandSet::UnassignedTranslated(), true,
       index == selected_item_);
   index++;
   AddSubMenusToMainMenu(main_menu, index);
   ProcessUserSelection(main_menu);
}

void CommandMenu::clicked(const juce::ModifierKeys& modifiers)
{
   try {
      if (modifiers.isPopupMenu()) { ShowDialogBasedOnMessageType(); }
      else {
         ProcessMenuItems();
      }
   }
   catch (const std::exception& e) {
      MIDI2LR_E_RESPONSE;
      throw;
   }
}