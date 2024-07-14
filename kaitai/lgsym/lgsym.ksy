meta:
  id: lg_sym
  file-extension: sym
  endian: le
  encoding: ascii
seq:
  - id: header
    type: header
  - id: sym_entries
    type: sym_entry
    repeat: expr
    repeat-expr: header.n_symbols
  - id: hash_type
    type: u4
    enum: hash_type_enum
  - id: hashes
    if: hash_type == hash_type_enum::hash_32
    type: u4
    repeat: expr
    repeat-expr: ((header.n_symbols + 1) & (~0 - 1))
  - id: dwarf_type
    type: u4
    enum: dwarf_type_enum
  - id: dwarf_data
    if: dwarf_type == dwarf_type_enum::dwarf_present
    type: dwarf_data
  - id: string_table
    type: string_data
types:
  header:
    seq:
      - id: magic
        contents:
          - 0xEE
          - 0x91
          - 0x27
          - 0xB1
      - id: unknown
        type: u4
      - id: size
        type: u4
      - id: n_symbols
        type: u4
      - id: tail_size
        type: u4
  sym_entry:
    seq:
      - id: addr
        type: u4
      - id: end
        type: u4
      - id: sym_name_of
        type: u4
  dwarf_union:
    instances:
      dwarf_type:
        pos: 0
        type: u4
      string_table:
        pos: 0
        type: string_data
  dwarf_entry:
    seq:
      - id: d1
        type: u4
      - id: d2
        type: u4
  dwarf_data:
    seq:
      - id: n_dwarf_lst
        type: u4
      - id: dwarf_data_size
        type: u4
      - id: dwarf_lst
        type: dwarf_entry
        repeat: expr
        repeat-expr: n_dwarf_lst
      - id: dwarf_data
        size: dwarf_data_size
  string_data:
    seq:
      - id: entries
        type: strz
        repeat: expr
        repeat-expr: _root.header.n_symbols
enums:
  hash_type_enum:
    0: hash_none
    2: hash_32
  dwarf_type_enum:
    0: dwarf_none
    1: dwarf_present
