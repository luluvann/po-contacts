import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:po_contacts_flutter/assets/i18n.dart';
import 'package:po_contacts_flutter/controller/main_controller.dart';
import 'package:po_contacts_flutter/model/data/labeled_field.dart';

class CategorizedEditableItem {
  String textValue;
  LabeledFieldLabelType labelType;
  String labelValue;

  CategorizedEditableItem(
    this.textValue,
    this.labelType,
    this.labelValue,
  );
}

class EditableItemCategory {
  LabeledFieldLabelType labelType;
  String labelValue;

  EditableItemCategory(
    this.labelType,
    this.labelValue,
  );

  @override
  int get hashCode => labelType.hashCode + labelValue.hashCode;

  @override
  bool operator ==(o) =>
      o is EditableItemCategory && o.labelType.index == labelType.index && o.labelValue == labelValue;
}

abstract class EditCategorizedItemsForm<T> extends StatefulWidget {
  final List<T> initialItems;
  final Function(List<T> updatedItems) onDataChanged;

  EditCategorizedItemsForm(this.initialItems, {this.onDataChanged});

  _EditCategorizedItemsFormState createState() => _EditCategorizedItemsFormState();

  void notifyDataChanged(final List<CategorizedEditableItem> currentItems) {
    if (onDataChanged == null) {
      return;
    }
    onDataChanged(_toGenericItems(currentItems));
  }

  List<CategorizedEditableItem> fromGenericItems(final List<T> genericItems) {
    final List<CategorizedEditableItem> res = [];
    for (final T gi in genericItems) {
      res.add(fromGenericItem(gi));
    }
    return res;
  }

  List<T> _toGenericItems(final List<CategorizedEditableItem> categorizedItems) {
    final List<T> res = [];
    for (final CategorizedEditableItem ci in categorizedItems) {
      res.add(toGenericItem(ci));
    }
    return res;
  }

  List<LabeledFieldLabelType> getAllowedLabelTypes();

  CategorizedEditableItem fromGenericItem(final T item);

  T toGenericItem(final CategorizedEditableItem item);

  String getEntryHintStringKey();

  List<TextInputFormatter> getInputFormatters();

  TextInputType getInputKeyboardType() {
    return TextInputType.text;
  }

  String validateValue(final String value) {
    return null;
  }

  String getAddEntryActionStringKey();
}

class _EditCategorizedItemsFormState extends State<EditCategorizedItemsForm> {
  final Set<String> customLabelTypeNames = Set<String>();
  final List<CategorizedEditableItem> currentItems = [];

  List<DropdownMenuItem<EditableItemCategory>> getDropDownMenuItems() {
    final List<LabeledFieldLabelType> labelTypes = widget.getAllowedLabelTypes();
    final List<DropdownMenuItem<EditableItemCategory>> res = [];
    for (final LabeledFieldLabelType lt in labelTypes) {
      if (lt == LabeledFieldLabelType.custom) {
        continue;
      }
      final String labelText = I18n.getString(LabeledField.getTypeNameStringKey(lt));
      res.add(DropdownMenuItem<EditableItemCategory>(
        value: EditableItemCategory(lt, labelText),
        child: Text(labelText),
      ));
    }
    for (final String customName in customLabelTypeNames) {
      res.add(DropdownMenuItem<EditableItemCategory>(
        value: EditableItemCategory(LabeledFieldLabelType.custom, customName),
        child: Text(customName),
      ));
    }
    res.add(DropdownMenuItem<EditableItemCategory>(
      value: EditableItemCategory(LabeledFieldLabelType.custom, ''),
      child: Text(I18n.getString(LabeledField.getTypeNameStringKey(LabeledFieldLabelType.custom))),
    ));
    return res;
  }

  EditableItemCategory getDropDownValue(final CategorizedEditableItem item) {
    if (item.labelType == LabeledFieldLabelType.custom) {
      return EditableItemCategory(item.labelType, item.labelValue);
    } else {
      final String labelText = I18n.getString(LabeledField.getTypeNameStringKey(item.labelType));
      return EditableItemCategory(item.labelType, labelText);
    }
  }

  @override
  void initState() {
    if (widget.initialItems != null) {
      currentItems.addAll(widget.fromGenericItems(widget.initialItems));
    }
    for (final CategorizedEditableItem item in currentItems) {
      if (item.labelType == LabeledFieldLabelType.custom && item.labelValue.isNotEmpty) {
        customLabelTypeNames.add(item.labelValue);
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    for (int i = 0; i < currentItems.length; i++) {
      final int itemIndex = i;
      final CategorizedEditableItem item = currentItems[itemIndex];
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: item.textValue,
                decoration: InputDecoration(
                  labelText: I18n.getString(widget.getEntryHintStringKey()),
                ),
                inputFormatters: widget.getInputFormatters(),
                keyboardType: widget.getInputKeyboardType(),
                validator: (final String value) {
                  if (value.isEmpty) {
                    return I18n.getString(I18n.string.field_cannot_be_empty);
                  }
                  return widget.validateValue(value);
                },
                onChanged: (nameValue) {
                  setState(() {
                    item.textValue = nameValue;
                    widget.notifyDataChanged(currentItems);
                  });
                },
              ),
            ),
            DropdownButton<EditableItemCategory>(
              value: getDropDownValue(item),
              icon: Icon(Icons.arrow_downward),
              iconSize: 24,
              onChanged: (EditableItemCategory newValue) {
                if (newValue.labelType == LabeledFieldLabelType.custom && newValue.labelValue.isEmpty) {
                  MainController.get().showTextInputDialog(
                    context,
                    I18n.string.custom_label,
                    (final String customLabelString) {
                      if (customLabelString == null || customLabelString.isEmpty) {
                        return;
                      }
                      setState(() {
                        item.labelType = LabeledFieldLabelType.custom;
                        item.labelValue = customLabelString;
                        customLabelTypeNames.add(customLabelString);
                        widget.notifyDataChanged(currentItems);
                      });
                    },
                  );
                  return;
                }
                setState(() {
                  item.labelType = newValue.labelType;
                  item.labelValue = newValue.labelValue;
                  widget.notifyDataChanged(currentItems);
                });
              },
              items: getDropDownMenuItems(),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: I18n.getString(I18n.string.remove_entry),
              onPressed: () {
                setState(() {
                  currentItems.removeAt(itemIndex);
                  widget.notifyDataChanged(currentItems);
                });
              },
            ),
          ],
        ),
      );
    }
    rows.add(
      FlatButton(
        color: Colors.green,
        textColor: Colors.white,
        padding: EdgeInsets.all(8.0),
        splashColor: Colors.greenAccent,
        onPressed: () {
          setState(() {
            currentItems.add(CategorizedEditableItem('', widget.getAllowedLabelTypes()[0], ''));
          });
        },
        child: Text(I18n.getString(widget.getAddEntryActionStringKey())),
      ),
    );
    return Column(
      key: Key('${currentItems.length}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
