import 'dart:io';

import 'package:po_contacts_flutter/controller/main_controller.dart';
import 'package:po_contacts_flutter/controller/vcard/vcf_file_reader.dart';
import 'package:po_contacts_flutter/controller/vcard/vcf_serializer.dart';
import 'package:po_contacts_flutter/model/data/contact.dart';

class ImportController {
  bool _currentlyImporting = false;

  void startImportIfNeeded() {
    _getImportableFileId().then((final String fileId) {
      _startImportProcedure(fileId);
    });
  }

  Future<String> _getImportableFileId() async {
    return await MainController.get().nativeApisController.getInboxFileId();
  }

  void _startImportProcedure(final String fileId) {
    if (fileId == null) {
      return;
    }
    if (_currentlyImporting) {
      return;
    }
    _currentlyImporting = true;

    MainController.get().promptUserForFileImport((userApprovedImport) {
      if (userApprovedImport) {
        _importFileWithId(fileId);
      } else {
        _discardFileWithId(fileId);
        _currentlyImporting = false;
      }
    });
  }

  void _discardFileWithId(final String fileId) {
    MainController.get().nativeApisController.discardInboxFileId(fileId);
  }

  void _importFileWithId(final String fileId) async {
    final String inboxFilePath = await MainController.get().nativeApisController.getCopiedInboxFilePath(fileId);
    final List<ContactBuilder> readContacts = VCFSerializer.readFromVCF(new VCFFileReader(new File(inboxFilePath)));
    for (final ContactBuilder cb in readContacts) {
      MainController.get().model.addContact(cb);
    }
    _currentlyImporting = false;
  }
}
