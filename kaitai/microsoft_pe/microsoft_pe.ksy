meta:
  id: microsoft_pe
  title: Microsoft PE (Portable Executable) file format
  application: Microsoft Windows
  file-extension:
    - exe
    - dll
    - sys
  xref:
    justsolve: Portable_Executable
    pronom: x-fmt/411
    wikidata: Q1076355
  tags:
    - executable
    - windows
  license: CC0-1.0
  ks-version: 0.7
  endian: le
doc-ref: https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
seq:
  - id: mz
    type: mz_placeholder
instances:
  pe:
    pos: mz.ofs_pe
    type: pe_header
enums:
  pe_format:
    0x107: rom_image
    0x10b: pe32
    0x20b: pe32_plus
types:
  mz_placeholder:
    seq:
      - id: magic
        contents: "MZ"
      - id: data1
        size: 0x3a
      - id: ofs_pe
        type: u4
        doc: In PE file, an offset to PE header
  pe_header:
    seq:
      - id: pe_signature
        contents: ["PE", 0, 0]
      - id: coff_hdr
        type: coff_header
      - id: optional_hdr
        type: optional_header
        size: coff_hdr.size_of_optional_header
      - id: sections
        repeat: expr
        repeat-expr: coff_hdr.number_of_sections
        type: section
    instances:
      maybe_certificate_table:
        # The virtual address value from the Certificate Table entry
        # in the Optional Header Data Directory is a **file offset**
        # to the first attribute certificate entry.
        pos: optional_hdr.data_dirs.certificate_table.virtual_address
        size: optional_hdr.data_dirs.certificate_table.size
        type: certificate_table
        if: optional_hdr.data_dirs.certificate_table.virtual_address != 0
        
      maybe_resources:
        if: optional_hdr.data_dirs.resource_table.rva.finder.found
        pos: optional_hdr.data_dirs.resource_table.rva.file_offset
        type: resource_directory
        
      maybe_relocations:
        if: optional_hdr.data_dirs.base_relocation_table.rva.finder.found
        pos: optional_hdr.data_dirs.base_relocation_table.rva.file_offset
        type: base_relocation_block_reader
      
      maybe_bound_imports:
        if: optional_hdr.data_dirs.bound_import.rva.finder.found
        pos: optional_hdr.data_dirs.bound_import.rva.file_offset
        type: bound_imports_directory
      
      maybe_imports:
        if: optional_hdr.data_dirs.import_table.rva.finder.found
        pos: optional_hdr.data_dirs.import_table.rva.file_offset
        type: import_directory

      maybe_exports:
        if: optional_hdr.data_dirs.export_table.rva.finder.found
        pos: optional_hdr.data_dirs.export_table.rva.file_offset
        type: export_directory
  bound_import_entry:
    seq:
      - id: time_date_stamp
        type: u4
      - id: offset_module_name
        type: u2
      - id: reserved
        type: u2
  bound_imports_directory_header:
    seq:
      - id: time_date_stamp
        type: u4
      - id: offset_module_name
        type: u2
      - id: number_of_module_forwarder_refs
        type: u2
  bound_imports_directory:
    seq:
      - id: header
        type: bound_imports_directory_header
      - id: items
        type: bound_import_entry
        repeat: expr
        repeat-expr: header.number_of_module_forwarder_refs
  base_relocation_entry:
    enums:
      based_relocation_type:
        0: based_absolute
        1: high
        2: low
        3: high_low
        4: high_adj
        5: machine_specific_5
        6: reserved
        7: machine_specific_7
        8: machine_specific_8
        9: machine_specific_9
        10: dir64
      ia64_relocation_type:
        9: imm64
      mips_relocation_type:
        5: jmpaddr
        9: jmpaddr_16
      arm_relocation_type:
        5: arm_mov32
        7: thumb_mov32
    seq:
      - id: zzz_value
        type: u2
    instances:
      type:
        value: (zzz_value >> 12) & 0xF
        enum: based_relocation_type
      offset:
        value: zzz_value & 0xFFF
      value_file_offset:
        value: _parent.header.virtual_address.file_offset + offset
      value:
        io: _root._io
        pos: value_file_offset
        type: u4
  base_relocation_block_header:
    seq:
      - id: virtual_address
        type: rva32
      - id: size_of_block
        type: u4
  base_relocation_block:
    seq:
      - id: header
        type: base_relocation_block_header
      - id: entries
        type: base_relocation_entry
        repeat: expr
        repeat-expr: num_entries
    instances:
      num_entries:
        value: 'header.size_of_block > 8 ? ((header.size_of_block - 8) / 2) : 0'
  resource_directory_entry_offset:
    seq:
      - id: offset_to_data
        type: u4
    instances:
      data_is_directory:
        value: (offset_to_data >> 31) == 1
      offset_to_directory:
        value: offset_to_data & 0x7FFFFFFF
  resource_directory_entry_name:
    seq:
      - id: value
        type: u4
    instances:
      name_is_string:
        value: (value >> 31) == 1
      name_offset:
        value: value & 0x7FFFFFFF
      maybe_id:
        if: name_is_string == false
        value: value
      maybe_string:
        if: name_is_string
        io: _root._io
        pos: _root.pe.optional_hdr.data_dirs.resource_table.rva.file_offset + name_offset
        type: resource_directory_string_u
  resource_directory_string_u:
    seq:
      - id: length
        type: u2
      - id: name_string
        type: str
        encoding: UTF-16LE
        size: length * 2
  resource_data_entry:
    seq:
      - id: offset_to_data
        type: rva32
      - id: size
        type: u4
      - id: code_page
        type: u4
      - id: reserved
        type: u4
        
    instances:
      data:
        io: _root._io
        pos: offset_to_data.file_offset
        size: size
  resource_directory_entry:
    seq:
      - id: name
        type: resource_directory_entry_name
        size: sizeof<resource_directory_entry_name>
      - id: offset
        type: resource_directory_entry_offset
        size: sizeof<resource_directory_entry_offset>
    instances:
      maybe_child_directory:
        io: _root._io
        if: offset.data_is_directory
        pos: _root.pe.optional_hdr.data_dirs.resource_table.rva.file_offset + offset.offset_to_directory
        type: resource_directory
      maybe_data:
        io: _root._io
        if: offset.data_is_directory == false
        pos: _root.pe.optional_hdr.data_dirs.resource_table.rva.file_offset + offset.offset_to_data
        type: resource_data_entry
  rva_cstring64:
    seq:
      - id: rva
        type: rva64
    instances:
      value:
        value: rva.value
      maybe_string:
        if: value != 0
        io: _root._io
        pos: rva.file_offset
        type: str
        encoding: UTF-8
        terminator: 0
  rva_cstring32:
    seq:
      - id: rva
        type: rva32
    instances:
      value:
        value: rva.value
      maybe_string:
        if: value != 0
        io: _root._io
        pos: rva.file_offset
        type: str
        encoding: UTF-8
        terminator: 0
  rva_ilt:
    seq:
      - id: rva
        type: rva32
    instances:
      value:
        value: rva.value
      maybe_items32:
        if: _root.pe.optional_hdr.std.format == pe_format::pe32
        io: _root._io
        pos: rva.file_offset
        type: thunk32_descriptor_reader
      maybe_items64:
        if: _root.pe.optional_hdr.std.format == pe_format::pe32_plus
        io: _root._io
        pos: rva.file_offset
        type: thunk64_descriptor_reader
  import_by_name:
    seq:
      - id: hint
        type: u2
      - id: name
        type: str
        encoding: UTF-8
        terminator: 0
  name_ordinal:
    seq:
      - id: value
        type: u2
    instances:
      ordinal:
        value: _parent.base + value
  thunk_data32:
    seq:
      - id: value
        type: u4
    instances:
      is_ordinal_import:
        value: (value >> 31) == 1
      maybe_ordinal:
        if: is_ordinal_import == true
        value: value & 0xFFFF
      maybe_address_of_data:
        if: is_ordinal_import == false
        pos: 0
        type: rva32
      maybe_name:
        if: is_ordinal_import == false
        io: _root._io
        pos: maybe_address_of_data.file_offset
        type: import_by_name
        size-eos: true
  thunk_data64:
    seq:
      - id: value
        type: u8
    instances:
      is_ordinal_import:
        value: (value >> 63) == 1
      maybe_ordinal:
        if: is_ordinal_import == true
        value: value & 0xFFFF
      maybe_address_of_data:
        if: is_ordinal_import == false
        pos: 0
        type: rva64
      maybe_name:
        if: is_ordinal_import == false
        io: _root._io
        pos: maybe_address_of_data.file_offset
        type: import_by_name
        size-eos: true
  thunk_union:
    seq:
      - id: maybe_data32
        if: _root.pe.optional_hdr.std.format == pe_format::pe32
        type: thunk_data32
      - id: maybe_data64
        if: _root.pe.optional_hdr.std.format == pe_format::pe32_plus
        type: thunk_data64
  import_descriptor:
    seq: 
      - size: 4
      - id: time_date_stamp
        type: u4
      - id: forwarder_chain
        type: u4
      - id: name
        type: rva_cstring32
      - id: first_thunk
        type: rva_ilt
    instances:
      characteristics:
        pos: 0
        type: u4
      original_first_thunk:
        pos: 0
        type: rva_ilt
  import_directory:
    seq:
      - id: zzz_descriptors
        type: import_descriptor_reader
    instances:
      descriptors:
        value: zzz_descriptors.items
  exported_function:
    seq:
      - id: rva
        type: rva32
    params:
      - id: index
        type: u4
      - id: zzz_ordinal
        type: u4
    instances:
      name_index:
        value: index - _parent.number_of_unnamed_functions
      is_named:
        value: index >= _parent.number_of_unnamed_functions
      ordinal:
        value: 'is_named ? _parent.name_ordinals[name_index].ordinal : zzz_ordinal'
      maybe_name:
        if: index >= _parent.number_of_unnamed_functions
        value: _parent.names[name_index]
  export_directory:
    seq:
      - id: characteristics
        type: u4
      - id: time_date_stamp
        type: u4
      - id: major_version
        type: u2
      - id: minor_version
        type: u2
      - id: name
        type: u4
      - id: base
        type: u4
      - id: number_of_functions
        type: u4
      - id: number_of_names
        type: u4
      - id: address_of_functions
        type: rva32
      - id: address_of_names
        type: rva32
      - id: address_of_name_ordinals
        type: rva32
    instances:
      number_of_unnamed_functions:
        value: number_of_functions - number_of_names
      function_entries:
        io: _root._io
        pos: address_of_functions.file_offset
        type: exported_function(_index, base + _index)
        repeat: expr
        repeat-expr: number_of_functions
      names:
        io: _root._io
        pos: address_of_names.file_offset
        type: rva_cstring32
        repeat: expr
        repeat-expr: number_of_names
      name_ordinals:
        io: _root._io
        pos: address_of_name_ordinals.file_offset
        type: name_ordinal
        repeat: expr
        repeat-expr: number_of_names
  resource_directory:
    seq:
      - id: characteristics
        type: u4
      - id: time_date_stamp
        type: u4
      - id: major_version
        type: u2
      - id: minor_version
        type: u2
      - id: number_of_named_entries
        type: u2
      - id: number_of_id_entries
        type: u2
      - id: named_entries
        repeat: expr
        repeat-expr: number_of_named_entries
        type: resource_directory_entry
      - id: id_entries
        repeat: expr
        repeat-expr: number_of_id_entries
        type: resource_directory_entry
    instances:
      number_of_items:
        value: number_of_named_entries + number_of_id_entries
  coff_string_table_data:
    seq:
      - id: bytes
        type: u1
        repeat: eos
    instances:
      strings:
        pos: 0
        type: str
        repeat: eos
        encoding: UTF-8
        terminator: 0
  coff_string:
    params:
      - id: offset
        type: u4
    instances:
      str:
        io: _root._io
        pos: _root.pe.coff_hdr.pointer_to_symbol_table + (sizeof<coff_symbol> * _root.pe.coff_hdr.number_of_symbols) + offset
        type: str
        encoding: UTF-8
        terminator: 0
  coff_string_table:
    seq:
      - id: total_size
        type: u4
      - id: data
        size: total_size - 4
        type: coff_string_table_data
  coff_header:
    doc-ref: 3.3. COFF File Header (Object and Image)
    seq:
      - id: machine
        type: u2
        enum: machine_type
      - id: number_of_sections
        type: u2
      - id: time_date_stamp
        type: u4
      - id: pointer_to_symbol_table
        type: u4
      - id: number_of_symbols
        type: u4
      - id: size_of_optional_header
        type: u2
      - id: characteristics
        type: u2
    instances:
      symbol_table_size:
        value: number_of_symbols * 18
      symbol_name_table_offset:
        value: pointer_to_symbol_table + symbol_table_size
      symbol_name_table_size:
        pos: symbol_name_table_offset
        type: u4
      symbol_table:
        pos: pointer_to_symbol_table
        type: coff_symbol
        repeat: expr
        repeat-expr: number_of_symbols
      string_table:
        pos: pointer_to_symbol_table + (sizeof<coff_symbol> * number_of_symbols)
        type: coff_string_table
    enums:
      machine_type:
        # 3.3.1. Machine Types
        0x0: unknown
        0x1d3: am33
        0x8664: amd64
        0x1c0: arm
        0xaa64: arm64
        0x1c4: armnt
        0xebc: ebc
        0x14c: i386
        0x200: ia64
        0x9041: m32r
        0x266: mips16
        0x366: mipsfpu
        0x466: mipsfpu16
        0x1f0: powerpc
        0x1f1: powerpcfp
        0x166: r4000
        0x5032: riscv32
        0x5064: riscv64
        0x5128: riscv128
        0x1a2: sh3
        0x1a3: sh3dsp
        0x1a6: sh4
        0x1a8: sh5
        0x1c2: thumb
        0x169: wcemipsv2
        # Not mentioned in Microsoft documentation, but widely regarded
        0x184: alpha
  coff_symbol_function:
    seq:
      - id: tag_index
        type: u4
      - id: total_size
        type: u4
      - id: pointer_to_line_number
        type: u4
      - id: pointer_to_next_function
        type: u4
      - size: 2
  coff_symbol_bf_ef:
    seq:
      - size: 4
      - id: line_number
        type: u2
      - size: 6
      - id: pointer_to_next_function
        size: 4
      - size: 2
  coff_symbol_weak_external:
    seq:
      - id: tag_index
        type: u4
      - id: characteristics
        type: u4
      - size: 10
  coff_symbol_file:
    seq:
      - id: file_name
        type: str
        encoding: UTF-8
        size: 18
        pad-right: 0
  coff_symbol_section:
    enums:
      comdat_selection:
        1: no_duplicates
        2: any
        3: same_size
        4: exact_match
        5: associative
        6: largest
    seq:
      - id: length
        type: u4
      - id: number_of_relocations
        type: u2
      - id: number_of_line_numbers
        type: u2
      - id: checksum
        type: u4
      - id: number
        type: u2
      - id: comdat_selection
        type: u1
        enum: comdat_selection
      - size: 3
  coff_symbol_clr_token:
    seq:
      - id: b_aux_type
        contents: [0x01] # IMAGE_AUX_SYMBOL_TYPE_TOKEN_DEF 
      - id: b_reserved
        contents: [0x00]
      - id: symbol_table_index
        type: u4
      - size: 12
  coff_symbol_aux:
    instances:
      maybe_function:
        if: _parent.storage_class == coff_symbol::storage_class::external
          and _parent.type == coff_symbol::symbol_type::function
          and _parent.section_number > 0
        type: coff_symbol_function
  coff_symbol:
    enums:
      section_numbers:
        0: undefined
        0xFFFF: absolute # -1
        0xFFFE: debug # -2
      symbol_type:
        0: unknown
        1: void
        2: char
        3: short
        4: int
        5: long
        6: float
        7: double
        8: struct
        9: union
        10: enum
        11: member_of_enumeration
        12: byte
        13: word
        14: uint
        15: dword
        32: function
      storage_class:
        0: none
        1: automatic
        2: external
        3: static
        4: register
        5: external_def
        6: label
        7: undefined_label
        8: member_of_struct
        9: argument
        10: struct_tag
        11: member_of_union
        12: union_tag
        13: type_definition
        14: undefined_static
        15: enum_tag
        16: member_of_enum
        17: register_param
        18: bit_field
        100: block
        101: function
        102: end_of_struct
        103: file
        104: section
        105: weak_external
        107: clr_token
    seq:
      - id: invoke_data_start
        size: 0
        if: data_start >= 0
      - id: name_annoying
        type: annoyingstring
        size: 8
      #- id: name_zeroes
      #  type: u4
      #- id: name_offset
      #  type: u4
      - id: value
        type: u4
      - id: section_number
        type: u2
      - id: type
        type: u2
        enum: symbol_type
      - id: storage_class
        type: u1
        enum: storage_class
      - id: number_of_aux_symbols
        type: u1
    instances:
      maybe_aux_symbols:
        if: number_of_aux_symbols > 0
        pos: data_start + sizeof<coff_symbol>
        type: coff_symbol_aux
        repeat: expr
        repeat-expr: number_of_aux_symbols
        size: sizeof<coff_symbol>
      data_start:
        value: _io.pos
      #effective_name:
      #  value: name_zeroes == 0 ? name_from_offset : '"fixme"'
      #name_from_offset:
      #  io: _root._io
      #  pos: name_zeroes == 0 ? _parent.symbol_name_table_offset + name_offset : 0
      #  type: str
      #  terminator: 0
      #  encoding: ascii
      section_is_special:
        value: section_number == section_numbers::undefined.as<u2>
          or section_number == section_numbers::absolute.as<u2>
          or section_number == section_numbers::debug.as<u2>
      maybe_section_special:
        if: section_is_special
        value: section_number
        enum: section_numbers
      maybe_section:
        if: section_is_special == false
        value: _root.pe.sections[section_number - 1]
      maybe_data:
        if: section_is_special == false
        pos: maybe_section.pointer_to_raw_data + value
        size: 1
  annoyingstring:
    -webide-representation: '{name}'
    instances:
      name_zeroes:
        pos: 0
        type: u4
      name_offset:
        pos: 4
        type: u4
      maybe_name_from_offset:
        io: _root._io
        pos: 'name_zeroes == 0 ? _parent._parent.symbol_name_table_offset + name_offset : 0'
        type: str
        terminator: 0
        eos-error: false
        encoding: ASCII
        if: name_zeroes == 0
      maybe_name_from_short:
        pos: 0
        type: str
        terminator: 0
        eos-error: false
        encoding: ASCII
        if: name_zeroes != 0
      name:
        value: 'name_zeroes == 0 ? maybe_name_from_offset : maybe_name_from_short'
  optional_header:
    seq:
      - id: std
        type: optional_header_std
      - id: windows
        type: optional_header_windows
      - id: data_dirs
        type: optional_header_data_dirs
  optional_header_std:
    seq:
      - id: format
        type: u2
        enum: pe_format
      - id: major_linker_version
        type: u1
      - id: minor_linker_version
        type: u1
      - id: size_of_code
        type: u4
      - id: size_of_initialized_data
        type: u4
      - id: size_of_uninitialized_data
        type: u4
      - id: address_of_entry_point
        type: u4
      - id: base_of_code
        type: u4
      - id: base_of_data
        type: u4
        if: format == pe_format::pe32
  optional_header_windows:
    seq:
      - id: image_base_32
        type: u4
        if: _parent.std.format == pe_format::pe32
      - id: image_base_64
        type: u8
        if: _parent.std.format == pe_format::pe32_plus
      - id: section_alignment
        type: u4
      - id: file_alignment
        type: u4
      - id: major_operating_system_version
        type: u2
      - id: minor_operating_system_version
        type: u2
      - id: major_image_version
        type: u2
      - id: minor_image_version
        type: u2
      - id: major_subsystem_version
        type: u2
      - id: minor_subsystem_version
        type: u2
      - id: win32_version_value
        type: u4
      - id: size_of_image
        type: u4
      - id: size_of_headers
        type: u4
      - id: check_sum
        type: u4
      - id: subsystem
        type: u2
        enum: subsystem_enum
      - id: dll_characteristics
        type: u2
      - id: size_of_stack_reserve_32
        type: u4
        if: _parent.std.format == pe_format::pe32
      - id: size_of_stack_reserve_64
        type: u8
        if: _parent.std.format == pe_format::pe32_plus
      - id: size_of_stack_commit_32
        type: u4
        if: _parent.std.format == pe_format::pe32
      - id: size_of_stack_commit_64
        type: u8
        if: _parent.std.format == pe_format::pe32_plus
      - id: size_of_heap_reserve_32
        type: u4
        if: _parent.std.format == pe_format::pe32
      - id: size_of_heap_reserve_64
        type: u8
        if: _parent.std.format == pe_format::pe32_plus
      - id: size_of_heap_commit_32
        type: u4
        if: _parent.std.format == pe_format::pe32
      - id: size_of_heap_commit_64
        type: u8
        if: _parent.std.format == pe_format::pe32_plus
      - id: loader_flags
        type: u4
      - id: number_of_rva_and_sizes
        type: u4
    enums:
      subsystem_enum:
        0: unknown
        1: native
        2: windows_gui
        3: windows_cui
        7: posix_cui
        9: windows_ce_gui
        10: efi_application
        11: efi_boot_service_driver
        12: efi_runtime_driver
        13: efi_rom
        14: xbox
        16: windows_boot_application
  optional_header_data_dirs:
    seq:
      - id: export_table
        type: data_dir_rva
      - id: import_table
        type: data_dir_rva
      - id: resource_table
        type: data_dir_rva
      - id: exception_table
        type: data_dir_rva
      - id: certificate_table
        type: data_dir
      - id: base_relocation_table
        type: data_dir_rva
      - id: debug
        type: data_dir_rva
      - id: architecture
        type: data_dir_rva
      - id: global_ptr
        type: data_dir_rva
      - id: tls_table
        type: data_dir_rva
      - id: load_config_table
        type: data_dir_rva
      - id: bound_import
        type: data_dir_rva
      - id: iat
        type: data_dir_rva
      - id: delay_import_descriptor
        type: data_dir_rva
      - id: clr_runtime_header
        type: data_dir_rva
  base_relocation_block_reader:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: items
        type: base_relocation_block
        repeat: until
        repeat-until: _io.eof or (_.header.virtual_address.value == 0 and _.header.size_of_block == 0)
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
  thunk64_descriptor_reader:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: buffer
        type: thunk_data64
        repeat: until
        repeat-until: _.value == 0
        size: sizeof<thunk_data64>
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
      items_size:
        value: items_end - sizeof<thunk_data64> - items_start
      items_count:
        value: items_size / sizeof<thunk_data64>
      items:
        pos: items_start
        repeat: expr
        repeat-expr: items_count
        type: thunk_union
        size: sizeof<thunk_data64>
  thunk32_descriptor_reader:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: buffer
        type: thunk_data32
        repeat: until
        repeat-until: _.value == 0
        size: sizeof<thunk_data32>
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
      items_size:
        value: items_end - sizeof<thunk_data32> - items_start
      items_count:
        value: items_size / sizeof<thunk_data32>
      items:
        pos: items_start
        repeat: expr
        repeat-expr: items_count
        type: thunk_union
        size: sizeof<thunk_data32>
  import_descriptor_reader:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: buffer
        type: import_descriptor
        repeat: until
        repeat-until:  _.name.value == 0 and _.first_thunk.value == 0
        size: sizeof<import_descriptor>
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
      items_size:
        value: items_end - sizeof<import_descriptor> - items_start
      items_count:
        value: items_size / sizeof<import_descriptor>
      items:
        pos: items_start
        repeat: expr
        repeat-expr: items_count
        type: import_descriptor
        size: sizeof<import_descriptor>
  section_finder32:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: discard
        type: section
        repeat: until
        repeat-until: _io.eof or (_parent.value >= _.rva and _parent.value < (_.rva + _.virtual_size))
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
      discard_size:
        value: items_end - items_start
      found:
        value: discard_size != _io.size
      section_index:
        if: found
        value: (discard_size - sizeof<section>) / sizeof<section>
      section:
        if: found
        value: _root.pe.sections[section_index]
  section_finder64:
    seq:
      - id: invoke_items_start
        size: 0
        if: items_start >= 0
      - id: discard
        type: section
        repeat: until
        repeat-until: _io.eof or (_parent.value >= _.rva and _parent.value < (_.rva + _.virtual_size))
      - id: invoke_items_end
        size: 0
        if: items_end >= 0
    instances:
      items_start:
        value: _io.pos
      items_end:
        value: _io.pos
      discard_size:
        value: items_end - items_start
      found:
        value: discard_size != _io.size
      section_index:
        if: found
        value: (discard_size - sizeof<section>) / sizeof<section>
      section:
        if: found
        value: _root.pe.sections[section_index]
  rva64:
    seq:
      - id: value
        type: u8
    instances:
      finder:
        io: _root._io
        pos: _root.mz.ofs_pe + 4 + sizeof<coff_header> +  _root.pe.coff_hdr.size_of_optional_header
        size: sizeof<section> * _root.pe.coff_hdr.number_of_sections
        type: section_finder64
      file_offset: 
        if: finder.found
        value: value - finder.section.rva + finder.section.pointer_to_raw_data
  rva32:
    seq:
      - id: value
        type: u4
    instances:
      finder:
        io: _root._io
        pos: _root.mz.ofs_pe + 4 + sizeof<coff_header> +  _root.pe.coff_hdr.size_of_optional_header
        size: sizeof<section> * _root.pe.coff_hdr.number_of_sections
        type: section_finder32
      file_offset: 
        if: finder.found
        value: value - finder.section.rva + finder.section.pointer_to_raw_data
  data_dir:
    seq:
      - id: virtual_address
        type: u4
      - id: size
        type: u4
  data_dir_rva:
    seq:
      - id: rva
        type: rva32
      - id: size
        type: u4
  section_name:
    params:
      - id: zzz_name
        type: str
    instances:
      is_indexed_name:
        value: zzz_name.substring(0, 1) == '/'
      str_offset:
        if: is_indexed_name == true
        value: zzz_name.substring(1, zzz_name.length).to_i
      indexed_name:
        if: is_indexed_name
        type: coff_string(str_offset)
      name:
        value: 'is_indexed_name ? indexed_name.str : zzz_name'
  section:
    -webide-representation: "{name}"
    seq:
      - id: zzz_name  
        type: str
        encoding: UTF-8
        size: 8
        pad-right: 0
      - id: virtual_size
        type: u4
      - id: rva
        type: u4
      - id: size_of_raw_data
        type: u4
      - id: pointer_to_raw_data
        type: u4
      - id: pointer_to_relocations
        type: u4
      - id: pointer_to_linenumbers
        type: u4
      - id: number_of_relocations
        type: u2
      - id: number_of_linenumbers
        type: u2
      - id: characteristics
        type: u4
    instances:
      name:
        type: section_name(zzz_name)
      body:
        pos: pointer_to_raw_data
        size: size_of_raw_data
  certificate_table:
    seq:
      - id: items
        type: certificate_entry
        repeat: eos
  certificate_entry:
    doc-ref: 'https://docs.microsoft.com/en-us/windows/desktop/debug/pe-format#the-attribute-certificate-table-image-only'
    enums:
      certificate_revision:
        0x0100:
          id: revision_1_0
          doc: |
            Version 1, legacy version of the Win_Certificate structure.
            It is supported only for purposes of verifying legacy Authenticode signatures
        0x0200:
          id: revision_2_0
          doc: Version 2 is the current version of the Win_Certificate structure.
      certificate_type_enum:
        0x0001:
          id: x509
          doc: |
            bCertificate contains an X.509 Certificate
            Not Supported
        0x0002:
          id: pkcs_signed_data
          doc: 'bCertificate contains a PKCS#7 SignedData structure'
        0x0003:
          id: reserved_1
          doc: 'Reserved'
        0x0004:
          id: ts_stack_signed
          doc: |
            Terminal Server Protocol Stack Certificate signing
            Not Supported
    seq:
      - id: length
        -orig-id: dwLength
        type: u4
        doc: Specifies the length of the attribute certificate entry.
      - id: revision
        -orig-id: wRevision
        type: u2
        enum: certificate_revision
        doc: Contains the certificate version number.
      - id: certificate_type
        -orig-id: wCertificateType
        type: u2
        enum: certificate_type_enum
        doc: Specifies the type of content in bCertificate
      - id: certificate_bytes
        -orig-id: bCertificate
        size: length - 8
        doc: Contains a certificate, such as an Authenticode signature.
