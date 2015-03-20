# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Separate compilation of a Nit program
module separate_compiler

import abstract_compiler
import coloring
import rapid_type_analysis

# Add separate compiler specific options
redef class ToolContext
	# --separate
	var opt_separate = new OptionBool("Use separate compilation", "--separate")
	# --no-inline-intern
	var opt_no_inline_intern = new OptionBool("Do not inline call to intern methods", "--no-inline-intern")
	# --no-union-attribute
	var opt_no_union_attribute = new OptionBool("Put primitive attibutes in a box instead of an union", "--no-union-attribute")
	# --no-shortcut-equate
	var opt_no_shortcut_equate = new OptionBool("Always call == in a polymorphic way", "--no-shortcut-equal")
	# --no-tag-primitives
	var opt_no_tag_primitives = new OptionBool("Use only boxes for primitive types", "--no-tag-primitives")

	# --colors-are-symbols
	var opt_colors_are_symbols = new OptionBool("Store colors as symbols (link-boost)", "--colors-are-symbols")
	# --trampoline-call
	var opt_trampoline_call = new OptionBool("Use an indirection when calling", "--trampoline-call")
	# --guard-call
	var opt_guard_call = new OptionBool("Guard VFT calls with a direct call", "--guard-call")
	# --substitute-monomorph
	var opt_substitute_monomorph = new OptionBool("Replace monomorph trampoline with direct call (link-boost)", "--substitute-monomorph")
	# --link-boost
	var opt_link_boost = new OptionBool("Enable all link-boost optimizations", "--link-boost")

	# --inline-coloring-numbers
	var opt_inline_coloring_numbers = new OptionBool("Inline colors and ids (semi-global)", "--inline-coloring-numbers")
	# --inline-some-methods
	var opt_inline_some_methods = new OptionBool("Allow the separate compiler to inline some methods (semi-global)", "--inline-some-methods")
	# --direct-call-monomorph
	var opt_direct_call_monomorph = new OptionBool("Allow the separate compiler to direct call monomorph sites (semi-global)", "--direct-call-monomorph")
	# --direct-call-monomorph0
	var opt_direct_call_monomorph0 = new OptionBool("Allow the separate compiler to direct call monomorph sites (semi-global)", "--direct-call-monomorph0")
	# --skip-dead-methods
	var opt_skip_dead_methods = new OptionBool("Do not compile dead methods (semi-global)", "--skip-dead-methods")
	# --semi-global
	var opt_semi_global = new OptionBool("Enable all semi-global optimizations", "--semi-global")
	# --no-colo-dead-methods
	var opt_colo_dead_methods = new OptionBool("Force colorization of dead methods", "--colo-dead-methods")
	# --tables-metrics
	var opt_tables_metrics = new OptionBool("Enable static size measuring of tables used for vft, typing and resolution", "--tables-metrics")

	redef init
	do
		super
		self.option_context.add_option(self.opt_separate)
		self.option_context.add_option(self.opt_no_inline_intern)
		self.option_context.add_option(self.opt_no_union_attribute)
		self.option_context.add_option(self.opt_no_shortcut_equate)
		self.option_context.add_option(self.opt_no_tag_primitives)
		self.option_context.add_option(opt_colors_are_symbols, opt_trampoline_call, opt_guard_call, opt_direct_call_monomorph0, opt_substitute_monomorph, opt_link_boost)
		self.option_context.add_option(self.opt_inline_coloring_numbers, opt_inline_some_methods, opt_direct_call_monomorph, opt_skip_dead_methods, opt_semi_global)
		self.option_context.add_option(self.opt_colo_dead_methods)
		self.option_context.add_option(self.opt_tables_metrics)
	end

	redef fun process_options(args)
	do
		super

		var tc = self
		if tc.opt_semi_global.value then
			tc.opt_inline_coloring_numbers.value = true
			tc.opt_inline_some_methods.value = true
			tc.opt_direct_call_monomorph.value = true
			tc.opt_skip_dead_methods.value = true
		end
		if tc.opt_link_boost.value then
			tc.opt_colors_are_symbols.value = true
			tc.opt_substitute_monomorph.value = true
		end
		if tc.opt_substitute_monomorph.value then
			tc.opt_trampoline_call.value = true
		end
	end

	var separate_compiler_phase = new SeparateCompilerPhase(self, null)
end

class SeparateCompilerPhase
	super Phase
	redef fun process_mainmodule(mainmodule, given_mmodules) do
		if not toolcontext.opt_separate.value then return

		var modelbuilder = toolcontext.modelbuilder
		var analysis = modelbuilder.do_rapid_type_analysis(mainmodule)
		modelbuilder.run_separate_compiler(mainmodule, analysis)
	end
end

redef class ModelBuilder
	fun run_separate_compiler(mainmodule: MModule, runtime_type_analysis: nullable RapidTypeAnalysis)
	do
		var time0 = get_time
		self.toolcontext.info("*** GENERATING C ***", 1)

		var compiler = new SeparateCompiler(mainmodule, self, runtime_type_analysis)
		compiler.do_compilation
		compiler.display_stats

		var time1 = get_time
		self.toolcontext.info("*** END GENERATING C: {time1-time0} ***", 2)
		write_and_make(compiler)
	end

	# Count number of invocations by VFT
	private var nb_invok_by_tables = 0
	# Count number of invocations by direct call
	private var nb_invok_by_direct = 0
	# Count number of invocations by inlining
	private var nb_invok_by_inline = 0
end

# Singleton that store the knowledge about the separate compilation process
class SeparateCompiler
	super AbstractCompiler

	redef type VISITOR: SeparateCompilerVisitor

	# The result of the RTA (used to know live types and methods)
	var runtime_type_analysis: nullable RapidTypeAnalysis

	private var undead_types: Set[MType] = new HashSet[MType]
	private var live_unresolved_types: Map[MClassDef, Set[MType]] = new HashMap[MClassDef, HashSet[MType]]

	private var type_ids: Map[MType, Int] is noinit
	private var type_colors: Map[MType, Int] is noinit
	private var opentype_colors: Map[MType, Int] is noinit
	protected var method_colors: Map[PropertyLayoutElement, Int] is noinit
	protected var attr_colors: Map[MAttribute, Int] is noinit

	init do
		var file = new_file("nit.common")
		self.header = new CodeWriter(file)
		self.compile_box_kinds
	end

	redef fun do_compilation
	do
		var compiler = self
		compiler.compile_header

		var c_name = mainmodule.c_name

		# compile class structures
		modelbuilder.toolcontext.info("Property coloring", 2)
		compiler.new_file("{c_name}.classes")
		compiler.do_property_coloring
		compiler.compile_class_infos
		for m in mainmodule.in_importation.greaters do
			for mclass in m.intro_mclasses do
				#if mclass.kind == abstract_kind or mclass.kind == interface_kind then continue
				compiler.compile_class_to_c(mclass)
			end
		end

		# The main function of the C
		compiler.new_file("{c_name}.main")
		compiler.compile_nitni_global_ref_functions
		compiler.compile_main_function
		compiler.compile_finalizer_function
		compiler.link_mmethods

		# compile methods
		for m in mainmodule.in_importation.greaters do
			modelbuilder.toolcontext.info("Generate C for module {m.full_name}", 2)
			compiler.new_file("{m.c_name}.sep")
			compiler.compile_module_to_c(m)
		end

		# compile live & cast type structures
		modelbuilder.toolcontext.info("Type coloring", 2)
		compiler.new_file("{c_name}.types")
		compiler.compile_types
	end

	# Color and compile type structures and cast information
	fun compile_types
	do
		var compiler = self

		var mtypes = compiler.do_type_coloring
		for t in mtypes do
			compiler.compile_type_to_c(t)
		end
		# compile remaining types structures (useless but needed for the symbol resolution at link-time)
		for t in compiler.undead_types do
			if mtypes.has(t) then continue
			compiler.compile_type_to_c(t)
		end

	end

	redef fun compile_header_structs do
		self.header.add_decl("typedef void(*nitmethod_t)(void); /* general C type representing a Nit method. */")
		self.compile_header_attribute_structs
		self.header.add_decl("struct class \{ int box_kind; nitmethod_t vft[]; \}; /* general C type representing a Nit class. */")

		# With resolution_table_table, all live type resolution are stored in a big table: resolution_table
		self.header.add_decl("struct type \{ int id; const char *name; int color; short int is_nullable; const struct types *resolution_table; int table_size; int type_table[]; \}; /* general C type representing a Nit type. */")
		self.header.add_decl("struct instance \{ const struct type *type; const struct class *class; nitattribute_t attrs[]; \}; /* general C type representing a Nit instance. */")
		self.header.add_decl("struct types \{ int dummy; const struct type *types[]; \}; /* a list types (used for vts, fts and unresolved lists). */")
		self.header.add_decl("typedef struct instance val; /* general C type representing a Nit instance. */")

		if not modelbuilder.toolcontext.opt_no_tag_primitives.value then
			self.header.add_decl("extern const struct class *class_info[];")
			self.header.add_decl("extern const struct type *type_info[];")
		end
	end

	fun compile_header_attribute_structs
	do
		if modelbuilder.toolcontext.opt_no_union_attribute.value then
			self.header.add_decl("typedef void* nitattribute_t; /* general C type representing a Nit attribute. */")
		else
			self.header.add_decl("typedef union \{")
			self.header.add_decl("void* val;")
			for c, v in self.box_kinds do
				var t = c.mclass_type

				# `Pointer` reuse the `val` field
				if t.mclass.name == "Pointer" then continue

				self.header.add_decl("{t.ctype_extern} {t.ctypename};")
			end
			self.header.add_decl("\} nitattribute_t; /* general C type representing a Nit attribute. */")
		end
	end

	fun compile_box_kinds
	do
		# Collect all bas box class
		# FIXME: this is not completely fine with a separate compilation scheme
		for classname in ["Int", "Bool", "Char", "Float", "NativeString", "Pointer"] do
			var classes = self.mainmodule.model.get_mclasses_by_name(classname)
			if classes == null then continue
			assert classes.length == 1 else print classes.join(", ")
			self.box_kinds[classes.first] = self.box_kinds.length + 1
		end
	end

	var box_kinds = new HashMap[MClass, Int]

	fun box_kind_of(mclass: MClass): Int
	do
		#var pointer_type = self.mainmodule.pointer_type
		#if mclass.mclass_type.ctype == "val*" or mclass.mclass_type.is_subtype(self.mainmodule, mclass.mclass_type pointer_type) then
		if mclass.mclass_type.ctype_extern == "val*" then
			return 0
		else if mclass.kind == extern_kind and mclass.name != "NativeString" then
			return self.box_kinds[self.mainmodule.get_primitive_class("Pointer")]
		else
			return self.box_kinds[mclass]
		end

	end

	fun compile_color_consts(colors: Map[Object, Int]) do
		var v = new_visitor
		for m, c in colors do
			compile_color_const(v, m, c)
		end
	end

	fun compile_color_const(v: SeparateCompilerVisitor, m: Object, color: Int) do
		if color_consts_done.has(m) then return
		if m isa MEntity then
			if modelbuilder.toolcontext.opt_inline_coloring_numbers.value then
				self.provide_declaration(m.const_color, "#define {m.const_color} {color}")
			else if not modelbuilder.toolcontext.opt_colors_are_symbols.value or not v.compiler.target_platform.supports_linker_script then
				self.provide_declaration(m.const_color, "extern const int {m.const_color};")
				v.add("const int {m.const_color} = {color};")
			else
				# The color 'C' is the ``address'' of a false static variable 'XC'
				self.provide_declaration(m.const_color, "#define {m.const_color} ((long)&X{m.const_color})\nextern const void X{m.const_color};")
				if color == -1 then color = 0 # Symbols cannot be negative, so just use 0 for dead things
				# Teach the linker that the address of 'XC' is `color`.
				linker_script.add("X{m.const_color} = {color};")
			end
		else
			abort
		end
		color_consts_done.add(m)
	end

	private var color_consts_done = new HashSet[Object]

	# colorize classe properties
	fun do_property_coloring do

		var rta = runtime_type_analysis

		# Layouts
		var poset = mainmodule.flatten_mclass_hierarchy
		var mclasses = new HashSet[MClass].from(poset)
		var colorer = new POSetColorer[MClass]
		colorer.colorize(poset)

		# The dead methods, still need to provide a dead color symbol
		var dead_methods = new Array[MMethod]

		# lookup properties to build layout with
		var mmethods = new HashMap[MClass, Set[PropertyLayoutElement]]
		var mattributes = new HashMap[MClass, Set[MAttribute]]
		for mclass in mclasses do
			mmethods[mclass] = new HashSet[PropertyLayoutElement]
			mattributes[mclass] = new HashSet[MAttribute]
			for mprop in self.mainmodule.properties(mclass) do
				if mprop isa MMethod then
					if not modelbuilder.toolcontext.opt_colo_dead_methods.value and rta != null and not rta.live_methods.has(mprop) then
						dead_methods.add(mprop)
						continue
					end
					mmethods[mclass].add(mprop)
				else if mprop isa MAttribute then
					mattributes[mclass].add(mprop)
				end
			end
		end

		# Collect all super calls (dead or not)
		var all_super_calls = new HashSet[MMethodDef]
		for mmodule in self.mainmodule.in_importation.greaters do
			for mclassdef in mmodule.mclassdefs do
				for mpropdef in mclassdef.mpropdefs do
					if not mpropdef isa MMethodDef then continue
					if mpropdef.has_supercall then
						all_super_calls.add(mpropdef)
					end
				end
			end
		end

		# lookup super calls and add it to the list of mmethods to build layout with
		var super_calls
		if rta != null then
			super_calls = rta.live_super_sends
		else
			super_calls = all_super_calls
		end

		for mmethoddef in super_calls do
			var mclass = mmethoddef.mclassdef.mclass
			mmethods[mclass].add(mmethoddef)
			for descendant in mclass.in_hierarchy(self.mainmodule).smallers do
				mmethods[descendant].add(mmethoddef)
			end
		end

		# methods coloration
		var meth_colorer = new POSetBucketsColorer[MClass, PropertyLayoutElement](poset, colorer.conflicts)
		method_colors = meth_colorer.colorize(mmethods)
		method_tables = build_method_tables(mclasses, super_calls)
		compile_color_consts(method_colors)

		# attribute null color to dead methods and supercalls
		for mproperty in dead_methods do
			compile_color_const(new_visitor, mproperty, -1)
		end
		for mpropdef in all_super_calls do
			if super_calls.has(mpropdef) then continue
			compile_color_const(new_visitor, mpropdef, -1)
		end

		# attributes coloration
		var attr_colorer = new POSetBucketsColorer[MClass, MAttribute](poset, colorer.conflicts)
		attr_colors = attr_colorer.colorize(mattributes)
		attr_tables = build_attr_tables(mclasses)
		compile_color_consts(attr_colors)
	end

	fun build_method_tables(mclasses: Set[MClass], super_calls: Set[MMethodDef]): Map[MClass, Array[nullable MPropDef]] do
		var tables = new HashMap[MClass, Array[nullable MPropDef]]
		for mclass in mclasses do
			var table = new Array[nullable MPropDef]
			tables[mclass] = table

			var mproperties = self.mainmodule.properties(mclass)
			var mtype = mclass.intro.bound_mtype

			for mproperty in mproperties do
				if not mproperty isa MMethod then continue
				if not method_colors.has_key(mproperty) then continue
				var color = method_colors[mproperty]
				if table.length <= color then
					for i in [table.length .. color[ do
						table[i] = null
					end
				end
				table[color] = mproperty.lookup_first_definition(mainmodule, mtype)
			end

			for supercall in super_calls do
				if not mtype.collect_mclassdefs(mainmodule).has(supercall.mclassdef) then continue

				var color = method_colors[supercall]
				if table.length <= color then
					for i in [table.length .. color[ do
						table[i] = null
					end
				end
				var mmethoddef = supercall.lookup_next_definition(mainmodule, mtype)
				table[color] = mmethoddef
			end

		end
		return tables
	end

	fun build_attr_tables(mclasses: Set[MClass]): Map[MClass, Array[nullable MPropDef]] do
		var tables = new HashMap[MClass, Array[nullable MPropDef]]
		for mclass in mclasses do
			var table = new Array[nullable MPropDef]
			tables[mclass] = table

			var mproperties = self.mainmodule.properties(mclass)
			var mtype = mclass.intro.bound_mtype

			for mproperty in mproperties do
				if not mproperty isa MAttribute then continue
				if not attr_colors.has_key(mproperty) then continue
				var color = attr_colors[mproperty]
				if table.length <= color then
					for i in [table.length .. color[ do
						table[i] = null
					end
				end
				table[color] = mproperty.lookup_first_definition(mainmodule, mtype)
			end
		end
		return tables
	end

	# colorize live types of the program
	private fun do_type_coloring: POSet[MType] do
		# Collect types to colorize
		var live_types = runtime_type_analysis.live_types
		var live_cast_types = runtime_type_analysis.live_cast_types

		# Compute colors
		var poset = poset_from_mtypes(live_types, live_cast_types)
		var colorer = new POSetColorer[MType]
		colorer.colorize(poset)
		type_ids = colorer.ids
		type_colors = colorer.colors
		type_tables = build_type_tables(poset)

		# VT and FT are stored with other unresolved types in the big resolution_tables
		self.compute_resolution_tables(live_types)

		return poset
	end

	private fun poset_from_mtypes(mtypes, cast_types: Set[MType]): POSet[MType] do
		var poset = new POSet[MType]

		# Instead of doing the full matrix mtypes X cast_types,
		# a grouping is done by the base classes of the type so
		# that we compare only types whose base classes are in inheritance.

		var mtypes_by_class = new MultiHashMap[MClass, MType]
		for e in mtypes do
			var c = e.as_notnullable.as(MClassType).mclass
			mtypes_by_class[c].add(e)
			poset.add_node(e)
		end

		var casttypes_by_class = new MultiHashMap[MClass, MType]
		for e in cast_types do
			var c = e.as_notnullable.as(MClassType).mclass
			casttypes_by_class[c].add(e)
			poset.add_node(e)
		end

		for c1, ts1 in mtypes_by_class do
			for c2 in c1.in_hierarchy(mainmodule).greaters do
				var ts2 = casttypes_by_class[c2]
				for e in ts1 do
					for o in ts2 do
						if e == o then continue
						if e.is_subtype(mainmodule, null, o) then
							poset.add_edge(e, o)
						end
					end
				end
			end
		end
		return poset
	end

	# Build type tables
	fun build_type_tables(mtypes: POSet[MType]): Map[MType, Array[nullable MType]] do
		var tables = new HashMap[MType, Array[nullable MType]]
		for mtype in mtypes do
			var table = new Array[nullable MType]
			for sup in mtypes[mtype].greaters do
				var color = type_colors[sup]
				if table.length <= color then
					for i in [table.length .. color[ do
						table[i] = null
					end
				end
				table[color] = sup
			end
			tables[mtype] = table
		end
		return tables
	end

	# resolution_tables is used to perform a type resolution at runtime in O(1)
	private fun compute_resolution_tables(mtypes: Set[MType]) do
		# During the visit of the body of classes, live_unresolved_types are collected
		# and associated to
		# Collect all live_unresolved_types (visited in the body of classes)

		# Determinate fo each livetype what are its possible requested anchored types
		var mtype2unresolved = new HashMap[MClassType, Set[MType]]
		for mtype in self.runtime_type_analysis.live_types do
			var set = new HashSet[MType]
			for cd in mtype.collect_mclassdefs(self.mainmodule) do
				if self.live_unresolved_types.has_key(cd) then
					set.add_all(self.live_unresolved_types[cd])
				end
			end
			mtype2unresolved[mtype] = set
		end

		# Compute the table layout with the prefered method
		var colorer = new BucketsColorer[MType, MType]
		opentype_colors = colorer.colorize(mtype2unresolved)
		resolution_tables = self.build_resolution_tables(mtype2unresolved)

		# Compile a C constant for each collected unresolved type.
		# Either to a color, or to -1 if the unresolved type is dead (no live receiver can require it)
		var all_unresolved = new HashSet[MType]
		for t in self.live_unresolved_types.values do
			all_unresolved.add_all(t)
		end
		var all_unresolved_types_colors = new HashMap[MType, Int]
		for t in all_unresolved do
			if opentype_colors.has_key(t) then
				all_unresolved_types_colors[t] = opentype_colors[t]
			else
				all_unresolved_types_colors[t] = -1
			end
		end
		self.compile_color_consts(all_unresolved_types_colors)

		#print "tables"
		#for k, v in unresolved_types_tables.as(not null) do
		#	print "{k}: {v.join(", ")}"
		#end
		#print ""
	end

	fun build_resolution_tables(elements: Map[MClassType, Set[MType]]): Map[MClassType, Array[nullable MType]] do
		var tables = new HashMap[MClassType, Array[nullable MType]]
		for mclasstype, mtypes in elements do
			var table = new Array[nullable MType]
			for mtype in mtypes do
				var color = opentype_colors[mtype]
				if table.length <= color then
					for i in [table.length .. color[ do
						table[i] = null
					end
				end
				table[color] = mtype
			end
			tables[mclasstype] = table
		end
		return tables
	end

	# Separately compile all the method definitions of the module
	fun compile_module_to_c(mmodule: MModule)
	do
		var old_module = self.mainmodule
		self.mainmodule = mmodule
		for cd in mmodule.mclassdefs do
			for pd in cd.mpropdefs do
				if not pd isa MMethodDef then continue
				var rta = runtime_type_analysis
				if modelbuilder.toolcontext.opt_skip_dead_methods.value and rta != null and not rta.live_methoddefs.has(pd) then continue
				#print "compile {pd} @ {cd} @ {mmodule}"
				var r = pd.separate_runtime_function
				r.compile_to_c(self)
				var r2 = pd.virtual_runtime_function
				if r2 != r then r2.compile_to_c(self)

				# Generate trampolines
				if modelbuilder.toolcontext.opt_trampoline_call.value then
					r2.compile_trampolines(self)
				end
			end
		end
		self.mainmodule = old_module
	end

	# Process all introduced methods and compile some linking information (if needed)
	fun link_mmethods
	do
		if not modelbuilder.toolcontext.opt_substitute_monomorph.value and not modelbuilder.toolcontext.opt_guard_call.value then return

		for mmodule in mainmodule.in_importation.greaters do
			for cd in mmodule.mclassdefs do
				for m in cd.intro_mproperties do
					if not m isa MMethod then continue
					link_mmethod(m)
				end
			end
		end
	end

	# Compile some linking information (if needed)
	fun link_mmethod(m: MMethod)
	do
		var n2 = "CALL_" + m.const_color

		# Replace monomorphic call by a direct call to the virtual implementation
		var md = is_monomorphic(m)
		if md != null then
			linker_script.add("{n2} = {md.virtual_runtime_function.c_name};")
		end

		# If opt_substitute_monomorph then a trampoline is used, else a weak symbol is used
		if modelbuilder.toolcontext.opt_guard_call.value then
			var r = m.intro.virtual_runtime_function
			provide_declaration(n2, "{r.c_ret} {n2}{r.c_sig} __attribute__((weak));")
		end
	end

	# The single mmethodef called in case of monomorphism.
	# Returns nul if dead or polymorphic.
	fun is_monomorphic(m: MMethod): nullable MMethodDef
	do
		var rta = runtime_type_analysis
		if rta == null then
			# Without RTA, monomorphic means alone (uniq name)
			if m.mpropdefs.length == 1 then
				return m.mpropdefs.first
			else
				return null
			end
		else
			# With RTA, monomorphic means only live methoddef
			var res: nullable MMethodDef = null
			for md in m.mpropdefs do
				if rta.live_methoddefs.has(md) then
					if res != null then return null
					res = md
				end
			end
			return res
		end
	end

	# Globaly compile the type structure of a live type
	fun compile_type_to_c(mtype: MType)
	do
		assert not mtype.need_anchor
		var is_live = mtype isa MClassType and runtime_type_analysis.live_types.has(mtype)
		var is_cast_live = runtime_type_analysis.live_cast_types.has(mtype)
		var c_name = mtype.c_name
		var v = new SeparateCompilerVisitor(self)
		v.add_decl("/* runtime type {mtype} */")

		# extern const struct type_X
		self.provide_declaration("type_{c_name}", "extern const struct type type_{c_name};")

		# const struct type_X
		v.add_decl("const struct type type_{c_name} = \{")

		# type id (for cast target)
		if is_cast_live then
			v.add_decl("{type_ids[mtype]},")
		else
			v.add_decl("-1, /*CAST DEAD*/")
		end

		# type name
		v.add_decl("\"{mtype}\", /* class_name_string */")

		# type color (for cast target)
		if is_cast_live then
			v.add_decl("{type_colors[mtype]},")
		else
			v.add_decl("-1, /*CAST DEAD*/")
		end

		# is_nullable bit
		if mtype isa MNullableType then
			v.add_decl("1,")
		else
			v.add_decl("0,")
		end

		# resolution table (for receiver)
		if is_live then
			var mclass_type = mtype.as_notnullable
			assert mclass_type isa MClassType
			if resolution_tables[mclass_type].is_empty then
				v.add_decl("NULL, /*NO RESOLUTIONS*/")
			else
				compile_type_resolution_table(mtype)
				v.require_declaration("resolution_table_{c_name}")
				v.add_decl("&resolution_table_{c_name},")
			end
		else
			v.add_decl("NULL, /*DEAD*/")
		end

		# cast table (for receiver)
		if is_live then
			v.add_decl("{self.type_tables[mtype].length},")
			v.add_decl("\{")
			for stype in self.type_tables[mtype] do
				if stype == null then
					v.add_decl("-1, /* empty */")
				else
					v.add_decl("{type_ids[stype]}, /* {stype} */")
				end
			end
			v.add_decl("\},")
		else
			v.add_decl("0, \{\}, /*DEAD TYPE*/")
		end
		v.add_decl("\};")
	end

	fun compile_type_resolution_table(mtype: MType) do

		var mclass_type = mtype.as_notnullable.as(MClassType)

		# extern const struct resolution_table_X resolution_table_X
		self.provide_declaration("resolution_table_{mtype.c_name}", "extern const struct types resolution_table_{mtype.c_name};")

		# const struct fts_table_X fts_table_X
		var v = new_visitor
		v.add_decl("const struct types resolution_table_{mtype.c_name} = \{")
		v.add_decl("0, /* dummy */")
		v.add_decl("\{")
		for t in self.resolution_tables[mclass_type] do
			if t == null then
				v.add_decl("NULL, /* empty */")
			else
				# The table stores the result of the type resolution
				# Therefore, for a receiver `mclass_type`, and a unresolved type `t`
				# the value stored is tv.
				var tv = t.resolve_for(mclass_type, mclass_type, self.mainmodule, true)
				# FIXME: What typeids means here? How can a tv not be live?
				if type_ids.has_key(tv) then
					v.require_declaration("type_{tv.c_name}")
					v.add_decl("&type_{tv.c_name}, /* {t}: {tv} */")
				else
					v.add_decl("NULL, /* empty ({t}: {tv} not a live type) */")
				end
			end
		end
		v.add_decl("\}")
		v.add_decl("\};")
	end

	# Globally compile the table of the class mclass
	# In a link-time optimisation compiler, tables are globally computed
	# In a true separate compiler (a with dynamic loading) you cannot do this unfortnally
	fun compile_class_to_c(mclass: MClass)
	do
		var mtype = mclass.intro.bound_mtype
		var c_name = mclass.c_name

		var vft = self.method_tables[mclass]
		var attrs = self.attr_tables[mclass]
		var v = new_visitor

		var rta = runtime_type_analysis
		var is_dead = rta != null and not rta.live_classes.has(mclass) and mtype.ctype == "val*" and mclass.name != "NativeArray" and mclass.name != "Pointer"

		v.add_decl("/* runtime class {c_name} */")

		# Build class vft
		if not is_dead then
			self.provide_declaration("class_{c_name}", "extern const struct class class_{c_name};")
			v.add_decl("const struct class class_{c_name} = \{")
			v.add_decl("{self.box_kind_of(mclass)}, /* box_kind */")
			v.add_decl("\{")
			for i in [0 .. vft.length[ do
				var mpropdef = vft[i]
				if mpropdef == null then
					v.add_decl("NULL, /* empty */")
				else
					assert mpropdef isa MMethodDef
					if rta != null and not rta.live_methoddefs.has(mpropdef) then
						v.add_decl("NULL, /* DEAD {mclass.intro_mmodule}:{mclass}:{mpropdef} */")
						continue
					end
					var rf = mpropdef.virtual_runtime_function
					v.require_declaration(rf.c_name)
					v.add_decl("(nitmethod_t){rf.c_name}, /* pointer to {mclass.intro_mmodule}:{mclass}:{mpropdef} */")
				end
			end
			v.add_decl("\}")
			v.add_decl("\};")
		end

		if mtype.ctype != "val*" or mtype.mclass.name == "Pointer" then
			# Is a primitive type or the Pointer class, not any other extern class

			if mtype.is_tagged then return

			#Build instance struct
			self.header.add_decl("struct instance_{c_name} \{")
			self.header.add_decl("const struct type *type;")
			self.header.add_decl("const struct class *class;")
			self.header.add_decl("{mtype.ctype_extern} value;")
			self.header.add_decl("\};")

			if not rta.live_types.has(mtype) and mtype.mclass.name != "Pointer" then return

			#Build BOX
			self.provide_declaration("BOX_{c_name}", "val* BOX_{c_name}({mtype.ctype_extern});")
			v.add_decl("/* allocate {mtype} */")
			v.add_decl("val* BOX_{mtype.c_name}({mtype.ctype_extern} value) \{")
			v.add("struct instance_{c_name}*res = nit_alloc(sizeof(struct instance_{c_name}));")
			v.compiler.undead_types.add(mtype)
			v.require_declaration("type_{c_name}")
			v.add("res->type = &type_{c_name};")
			v.require_declaration("class_{c_name}")
			v.add("res->class = &class_{c_name};")
			v.add("res->value = value;")
			v.add("return (val*)res;")
			v.add("\}")

			if mtype.mclass.name != "Pointer" then return

			v = new_visitor
			self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const struct type* type);")
			v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}(const struct type* type) \{")
			if is_dead then
				v.add_abort("{mclass} is DEAD")
			else
				var res = v.new_named_var(mtype, "self")
				res.is_exact = true
				v.add("{res} = nit_alloc(sizeof(struct instance_{mtype.c_name}));")
				v.add("{res}->type = type;")
				hardening_live_type(v, "type")
				v.require_declaration("class_{c_name}")
				v.add("{res}->class = &class_{c_name};")
				v.add("((struct instance_{mtype.c_name}*){res})->value = NULL;")
				v.add("return {res};")
			end
			v.add("\}")
			return
		else if mclass.name == "NativeArray" then
			#Build instance struct
			self.header.add_decl("struct instance_{c_name} \{")
			self.header.add_decl("const struct type *type;")
			self.header.add_decl("const struct class *class;")
			# NativeArrays are just a instance header followed by a length and an array of values
			self.header.add_decl("int length;")
			self.header.add_decl("val* values[0];")
			self.header.add_decl("\};")

			#Build NEW
			self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(int length, const struct type* type);")
			v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}(int length, const struct type* type) \{")
			var res = v.get_name("self")
			v.add_decl("struct instance_{c_name} *{res};")
			var mtype_elt = mtype.arguments.first
			v.add("{res} = nit_alloc(sizeof(struct instance_{c_name}) + length*sizeof({mtype_elt.ctype}));")
			v.add("{res}->type = type;")
			hardening_live_type(v, "type")
			v.require_declaration("class_{c_name}")
			v.add("{res}->class = &class_{c_name};")
			v.add("{res}->length = length;")
			v.add("return (val*){res};")
			v.add("\}")
			return
		else if mtype.mclass.kind == extern_kind and mtype.mclass.name != "NativeString" then
			# Is an extern class (other than Pointer and NativeString)
			# Pointer is caught in a previous `if`, and NativeString is internal

			var pointer_type = mainmodule.pointer_type

			self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const struct type* type);")
			v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}(const struct type* type) \{")
			if is_dead then
				v.add_abort("{mclass} is DEAD")
			else
				var res = v.new_named_var(mtype, "self")
				res.is_exact = true
				v.add("{res} = nit_alloc(sizeof(struct instance_{pointer_type.c_name}));")
				v.add("{res}->type = type;")
				hardening_live_type(v, "type")
				v.require_declaration("class_{c_name}")
				v.add("{res}->class = &class_{c_name};")
				v.add("((struct instance_{pointer_type.c_name}*){res})->value = NULL;")
				v.add("return {res};")
			end
			v.add("\}")
			return
		end

		#Build NEW
		self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const struct type* type);")
		v.add_decl("/* allocate {mtype} */")
		v.add_decl("{mtype.ctype} NEW_{c_name}(const struct type* type) \{")
		if is_dead then
			v.add_abort("{mclass} is DEAD")
		else
			var res = v.new_named_var(mtype, "self")
			res.is_exact = true
			v.add("{res} = nit_alloc(sizeof(struct instance) + {attrs.length}*sizeof(nitattribute_t));")
			v.add("{res}->type = type;")
			hardening_live_type(v, "type")
			v.require_declaration("class_{c_name}")
			v.add("{res}->class = &class_{c_name};")
			self.generate_init_attr(v, res, mtype)
			v.set_finalizer res
			v.add("return {res};")
		end
		v.add("\}")
	end

	# Compile structures used to map tagged primitive values to their classes and types.
	# This method also determines which class will be tagged.
	fun compile_class_infos
	do
		if modelbuilder.toolcontext.opt_no_tag_primitives.value then return

		# Note: if you change the tagging scheme, do not forget to update
		# `autobox` and `extract_tag`
		var class_info = new Array[nullable MClass].filled_with(null, 4)
		for t in box_kinds.keys do
			# Note: a same class can be associated to multiple slots if one want to
			# use some Huffman coding.
			if t.name == "Int" then
				class_info[1] = t
			else if t.name == "Char" then
				class_info[2] = t
			else if t.name == "Bool" then
				class_info[3] = t
			else
				continue
			end
			t.mclass_type.is_tagged = true
		end

		# Compile the table for classes. The tag is used as an index
		var v = self.new_visitor
		v.add_decl "const struct class *class_info[4] = \{"
		for t in class_info do
			if t == null then
				v.add_decl("NULL,")
			else
				var s = "class_{t.c_name}"
				v.require_declaration(s)
				v.add_decl("&{s},")
			end
		end
		v.add_decl("\};")

		# Compile the table for types. The tag is used as an index
		v.add_decl "const struct type *type_info[4] = \{"
		for t in class_info do
			if t == null then
				v.add_decl("NULL,")
			else
				var s = "type_{t.c_name}"
				undead_types.add(t.mclass_type)
				v.require_declaration(s)
				v.add_decl("&{s},")
			end
		end
		v.add_decl("\};")
	end

	# Add a dynamic test to ensure that the type referenced by `t` is a live type
	fun hardening_live_type(v: VISITOR, t: String)
	do
		if not v.compiler.modelbuilder.toolcontext.opt_hardening.value then return
		v.add("if({t} == NULL) \{")
		v.add_abort("type null")
		v.add("\}")
		v.add("if({t}->table_size == 0) \{")
		v.add("PRINT_ERROR(\"Insantiation of a dead type: %s\\n\", {t}->name);")
		v.add_abort("type dead")
		v.add("\}")
	end

	redef fun new_visitor do return new SeparateCompilerVisitor(self)

	# Stats

	private var type_tables: Map[MType, Array[nullable MType]] = new HashMap[MType, Array[nullable MType]]
	private var resolution_tables: Map[MClassType, Array[nullable MType]] = new HashMap[MClassType, Array[nullable MType]]
	protected var method_tables: Map[MClass, Array[nullable MPropDef]] = new HashMap[MClass, Array[nullable MPropDef]]
	protected var attr_tables: Map[MClass, Array[nullable MPropDef]] = new HashMap[MClass, Array[nullable MPropDef]]

	redef fun display_stats
	do
		super
		if self.modelbuilder.toolcontext.opt_tables_metrics.value then
			display_sizes
		end
		if self.modelbuilder.toolcontext.opt_isset_checks_metrics.value then
			display_isset_checks
		end
		var tc = self.modelbuilder.toolcontext
		tc.info("# implementation of method invocation",2)
		var nb_invok_total = modelbuilder.nb_invok_by_tables + modelbuilder.nb_invok_by_direct + modelbuilder.nb_invok_by_inline
		tc.info("total number of invocations: {nb_invok_total}",2)
		tc.info("invocations by VFT send:     {modelbuilder.nb_invok_by_tables} ({div(modelbuilder.nb_invok_by_tables,nb_invok_total)}%)",2)
		tc.info("invocations by direct call:  {modelbuilder.nb_invok_by_direct} ({div(modelbuilder.nb_invok_by_direct,nb_invok_total)}%)",2)
		tc.info("invocations by inlining:     {modelbuilder.nb_invok_by_inline} ({div(modelbuilder.nb_invok_by_inline,nb_invok_total)}%)",2)
	end

	fun display_sizes
	do
		print "# size of subtyping tables"
		print "\ttotal \tholes"
		var total = 0
		var holes = 0
		for t, table in type_tables do
			total += table.length
			for e in table do if e == null then holes += 1
		end
		print "\t{total}\t{holes}"

		print "# size of resolution tables"
		print "\ttotal \tholes"
		total = 0
		holes = 0
		for t, table in resolution_tables do
			total += table.length
			for e in table do if e == null then holes += 1
		end
		print "\t{total}\t{holes}"

		print "# size of methods tables"
		print "\ttotal \tholes"
		total = 0
		holes = 0
		for t, table in method_tables do
			total += table.length
			for e in table do if e == null then holes += 1
		end
		print "\t{total}\t{holes}"

		print "# size of attributes tables"
		print "\ttotal \tholes"
		total = 0
		holes = 0
		for t, table in attr_tables do
			total += table.length
			for e in table do if e == null then holes += 1
		end
		print "\t{total}\t{holes}"
	end

	protected var isset_checks_count = 0
	protected var attr_read_count = 0

	fun display_isset_checks do
		print "# total number of compiled attribute reads"
		print "\t{attr_read_count}"
		print "# total number of compiled isset-checks"
		print "\t{isset_checks_count}"
	end

	redef fun compile_nitni_structs
	do
		self.header.add_decl """
struct nitni_instance \{
	struct nitni_instance *next,
		*prev; /* adjacent global references in global list */
	int count; /* number of time this global reference has been marked */
	struct instance *value;
\};
"""
		super
	end

	redef fun finalize_ffi_for_module(mmodule)
	do
		var old_module = self.mainmodule
		self.mainmodule = mmodule
		super
		self.mainmodule = old_module
	end
end

# A visitor on the AST of property definition that generate the C code of a separate compilation process.
class SeparateCompilerVisitor
	super AbstractCompilerVisitor

	redef type COMPILER: SeparateCompiler

	redef fun adapt_signature(m, args)
	do
		var msignature = m.msignature.resolve_for(m.mclassdef.bound_mtype, m.mclassdef.bound_mtype, m.mclassdef.mmodule, true)
		var recv = args.first
		if recv.mtype.ctype != m.mclassdef.mclass.mclass_type.ctype then
			args.first = self.autobox(args.first, m.mclassdef.mclass.mclass_type)
		end
		for i in [0..msignature.arity[ do
			var t = msignature.mparameters[i].mtype
			if i == msignature.vararg_rank then
				t = args[i+1].mtype
			end
			args[i+1] = self.autobox(args[i+1], t)
		end
	end

	redef fun unbox_signature_extern(m, args)
	do
		var msignature = m.msignature.resolve_for(m.mclassdef.bound_mtype, m.mclassdef.bound_mtype, m.mclassdef.mmodule, true)
		if not m.mproperty.is_init and m.is_extern then
			args.first = self.unbox_extern(args.first, m.mclassdef.mclass.mclass_type)
		end
		for i in [0..msignature.arity[ do
			var t = msignature.mparameters[i].mtype
			if i == msignature.vararg_rank then
				t = args[i+1].mtype
			end
			if m.is_extern then args[i+1] = self.unbox_extern(args[i+1], t)
		end
	end

	redef fun autobox(value, mtype)
	do
		if value.mtype == mtype then
			return value
		else if value.mtype.ctype == "val*" and mtype.ctype == "val*" then
			return value
		else if value.mtype.ctype == "val*" then
			if mtype.is_tagged then
				if mtype.name == "Int" then
					return self.new_expr("(long)({value})>>2", mtype)
				else if mtype.name == "Char" then
					return self.new_expr("(char)((long)({value})>>2)", mtype)
				else if mtype.name == "Bool" then
					return self.new_expr("(short int)((long)({value})>>2)", mtype)
				else
					abort
				end
			end
			return self.new_expr("((struct instance_{mtype.c_name}*){value})->value; /* autounbox from {value.mtype} to {mtype} */", mtype)
		else if mtype.ctype == "val*" then
			if value.mtype.is_tagged then
				if value.mtype.name == "Int" then
					return self.new_expr("(val*)({value}<<2|1)", mtype)
				else if value.mtype.name == "Char" then
					return self.new_expr("(val*)((long)({value})<<2|2)", mtype)
				else if value.mtype.name == "Bool" then
					return self.new_expr("(val*)((long)({value})<<2|3)", mtype)
				else
					abort
				end
			end
			var valtype = value.mtype.as(MClassType)
			if mtype isa MClassType and mtype.mclass.kind == extern_kind and mtype.mclass.name != "NativeString" then
				valtype = compiler.mainmodule.pointer_type
			end
			var res = self.new_var(mtype)
			if compiler.runtime_type_analysis != null and not compiler.runtime_type_analysis.live_types.has(valtype) then
				self.add("/*no autobox from {value.mtype} to {mtype}: {value.mtype} is not live! */")
				self.add("PRINT_ERROR(\"Dead code executed!\\n\"); show_backtrace(1);")
				return res
			end
			self.require_declaration("BOX_{valtype.c_name}")
			self.add("{res} = BOX_{valtype.c_name}({value}); /* autobox from {value.mtype} to {mtype} */")
			return res
		else if (value.mtype.ctype == "void*" and mtype.ctype == "void*") or
			(value.mtype.ctype == "char*" and mtype.ctype == "void*") or
			(value.mtype.ctype == "void*" and mtype.ctype == "char*") then
			return value
		else
			# Bad things will appen!
			var res = self.new_var(mtype)
			self.add("/* {res} left unintialized (cannot convert {value.mtype} to {mtype}) */")
			self.add("PRINT_ERROR(\"Cast error: Cannot cast %s to %s.\\n\", \"{value.mtype}\", \"{mtype}\"); show_backtrace(1);")
			return res
		end
	end

	redef fun unbox_extern(value, mtype)
	do
		if mtype isa MClassType and mtype.mclass.kind == extern_kind and
		   mtype.mclass.name != "NativeString" then
			var pointer_type = compiler.mainmodule.pointer_type
			var res = self.new_var_extern(mtype)
			self.add "{res} = ((struct instance_{pointer_type.c_name}*){value})->value; /* unboxing {value.mtype} */"
			return res
		else
			return value
		end
	end

	redef fun box_extern(value, mtype)
	do
		if mtype isa MClassType and mtype.mclass.kind == extern_kind and
		   mtype.mclass.name != "NativeString" then
			var valtype = compiler.mainmodule.pointer_type
			var res = self.new_var(mtype)
			if compiler.runtime_type_analysis != null and not compiler.runtime_type_analysis.live_types.has(value.mtype.as(MClassType)) then
				self.add("/*no boxing of {value.mtype}: {value.mtype} is not live! */")
				self.add("PRINT_ERROR(\"Dead code executed!\\n\"); show_backtrace(1);")
				return res
			end
			self.require_declaration("BOX_{valtype.c_name}")
			self.add("{res} = BOX_{valtype.c_name}({value}); /* boxing {value.mtype} */")
			self.require_declaration("type_{mtype.c_name}")
			self.add("{res}->type = &type_{mtype.c_name};")
			self.require_declaration("class_{mtype.c_name}")
			self.add("{res}->class = &class_{mtype.c_name};")
			return res
		else
			return value
		end
	end

	# Returns a C expression containing the tag of the value as a long.
	#
	# If the C expression is evaluated to 0, it means there is no tag.
	# Thus the expression can be used as a condition.
	fun extract_tag(value: RuntimeVariable): String
	do
		assert value.mtype.ctype == "val*"
		return "((long){value}&3)" # Get the two low bits
	end

	# Returns a C expression of the runtime class structure of the value.
	# The point of the method is to work also with primitive types.
	fun class_info(value: RuntimeVariable): String
	do
		if value.mtype.ctype == "val*" then
			if can_be_primitive(value) and not compiler.modelbuilder.toolcontext.opt_no_tag_primitives.value then
				var tag = extract_tag(value)
				return "({tag}?class_info[{tag}]:{value}->class)"
			end
			return "{value}->class"
		else
			compiler.undead_types.add(value.mtype)
			self.require_declaration("class_{value.mtype.c_name}")
			return "(&class_{value.mtype.c_name})"
		end
	end

	# Returns a C expression of the runtime type structure of the value.
	# The point of the method is to work also with primitive types.
	fun type_info(value: RuntimeVariable): String
	do
		if value.mtype.ctype == "val*" then
			if can_be_primitive(value) and not compiler.modelbuilder.toolcontext.opt_no_tag_primitives.value then
				var tag = extract_tag(value)
				return "({tag}?type_info[{tag}]:{value}->type)"
			end
			return "{value}->type"
		else
			compiler.undead_types.add(value.mtype)
			self.require_declaration("type_{value.mtype.c_name}")
			return "(&type_{value.mtype.c_name})"
		end
	end

	redef fun compile_callsite(callsite, args)
	do
		var rta = compiler.runtime_type_analysis
		# TODO: Inlining of new-style constructors with initializers
		if compiler.modelbuilder.toolcontext.opt_direct_call_monomorph.value and rta != null and callsite.mpropdef.initializers.is_empty then
			var tgs = rta.live_targets(callsite)
			if tgs.length == 1 then
				return direct_call(tgs.first, args)
			end
		end
		# Shortcut intern methods as they are not usually redefinable
		if callsite.mpropdef.is_intern and callsite.mproperty.name != "object_id" then
			# `object_id` is the only redefined intern method, so it can not be directly called.
			# TODO find a less ugly approach?
			return direct_call(callsite.mpropdef, args)
		end
		return super
	end

	# Fully and directly call a mpropdef
	#
	# This method is used by `compile_callsite`
	private fun direct_call(mpropdef: MMethodDef, args: Array[RuntimeVariable]): nullable RuntimeVariable
	do
		var res0 = before_send(mpropdef.mproperty, args)
		var res = call(mpropdef, mpropdef.mclassdef.bound_mtype, args)
		if res0 != null then
			assert res != null
			self.assign(res0, res)
			res = res0
		end
		add("\}") # close the before_send
		return res
	end
	redef fun send(mmethod, arguments)
	do
		if arguments.first.mcasttype.ctype != "val*" then
			# In order to shortcut the primitive, we need to find the most specific method
			# Howverr, because of performance (no flattening), we always work on the realmainmodule
			var m = self.compiler.mainmodule
			self.compiler.mainmodule = self.compiler.realmainmodule
			var res = self.monomorphic_send(mmethod, arguments.first.mcasttype, arguments)
			self.compiler.mainmodule = m
			return res
		end

		return table_send(mmethod, arguments, mmethod)
	end

	# Handle common special cases before doing the effective method invocation
	# This methods handle the `==` and `!=` methods and the case of the null receiver.
	# Note: a { is open in the generated C, that enclose and protect the effective method invocation.
	# Client must not forget to close the } after them.
	#
	# The value returned is the result of the common special cases.
	# If not null, client must compile it with the result of their own effective method invocation.
	#
	# If `before_send` can shortcut the whole message sending, a dummy `if(0){`
	# is generated to cancel the effective method invocation that will follow
	# TODO: find a better approach
	private fun before_send(mmethod: MMethod, arguments: Array[RuntimeVariable]): nullable RuntimeVariable
	do
		var res: nullable RuntimeVariable = null
		var recv = arguments.first
		var consider_null = not self.compiler.modelbuilder.toolcontext.opt_no_check_null.value or mmethod.name == "==" or mmethod.name == "!="
		var maybenull = (recv.mcasttype isa MNullableType or recv.mcasttype isa MNullType) and consider_null
		if maybenull then
			self.add("if ({recv} == NULL) \{")
			if mmethod.name == "==" or mmethod.name == "is_same_instance" then
				res = self.new_var(bool_type)
				var arg = arguments[1]
				if arg.mcasttype isa MNullableType then
					self.add("{res} = ({arg} == NULL);")
				else if arg.mcasttype isa MNullType then
					self.add("{res} = 1; /* is null */")
				else
					self.add("{res} = 0; /* {arg.inspect} cannot be null */")
				end
			else if mmethod.name == "!=" then
				res = self.new_var(bool_type)
				var arg = arguments[1]
				if arg.mcasttype isa MNullableType then
					self.add("{res} = ({arg} != NULL);")
				else if arg.mcasttype isa MNullType then
					self.add("{res} = 0; /* is null */")
				else
					self.add("{res} = 1; /* {arg.inspect} cannot be null */")
				end
			else
				self.add_abort("Receiver is null")
			end
			self.add("\} else \{")
		else
			self.add("\{")
		end
		if not self.compiler.modelbuilder.toolcontext.opt_no_shortcut_equate.value and (mmethod.name == "==" or mmethod.name == "!=" or mmethod.name == "is_same_instance") then
			# Recv is not null, thus if arg is, it is easy to conclude (and respect the invariants)
			var arg = arguments[1]
			if arg.mcasttype isa MNullType then
				if res == null then res = self.new_var(bool_type)
				if mmethod.name == "!=" then
					self.add("{res} = 1; /* arg is null and recv is not */")
				else # `==` and `is_same_instance`
					self.add("{res} = 0; /* arg is null but recv is not */")
				end
				self.add("\}") # closes the null case
				self.add("if (0) \{") # what follow is useless, CC will drop it
			end
		end
		return res
	end

	private fun table_send(mmethod: MMethod, arguments: Array[RuntimeVariable], mentity: MEntity): nullable RuntimeVariable
	do
		compiler.modelbuilder.nb_invok_by_tables += 1
		if compiler.modelbuilder.toolcontext.opt_invocation_metrics.value then add("count_invoke_by_tables++;")

		assert arguments.length == mmethod.intro.msignature.arity + 1 else debug("Invalid arity for {mmethod}. {arguments.length} arguments given.")
		var recv = arguments.first

		var res0 = before_send(mmethod, arguments)

		var runtime_function = mmethod.intro.virtual_runtime_function
		var msignature = runtime_function.called_signature

		var res: nullable RuntimeVariable
		var ret = msignature.return_mtype
		if ret == null then
			res = null
		else
			res = self.new_var(ret)
		end

		var ss = new FlatBuffer

		ss.append("{recv}")
		for i in [0..msignature.arity[ do
			var a = arguments[i+1]
			var t = msignature.mparameters[i].mtype
			if i == msignature.vararg_rank then
				t = arguments[i+1].mcasttype
			end
			a = self.autobox(a, t)
			ss.append(", {a}")
		end

		var const_color = mentity.const_color
		var ress
		if res != null then
			ress = "{res} = "
		else
			ress = ""
		end
		if mentity isa MMethod and compiler.modelbuilder.toolcontext.opt_direct_call_monomorph0.value then
			# opt_direct_call_monomorph0 is used to compare the efficiency of the alternative lookup implementation, ceteris paribus.
			# The difference with the non-zero option is that the monomorphism is looked-at on the mmethod level and not at the callsite level.
			# TODO: remove this mess and use per callsite service to detect monomorphism in a single place.
			var md = compiler.is_monomorphic(mentity)
			if md != null then
				var callsym = md.virtual_runtime_function.c_name
				self.require_declaration(callsym)
				self.add "{ress}{callsym}({ss}); /* {mmethod} on {arguments.first.inspect}*/"
			else
				self.require_declaration(const_color)
				self.add "{ress}(({runtime_function.c_funptrtype})({class_info(arguments.first)}->vft[{const_color}]))({ss}); /* {mmethod} on {arguments.first.inspect}*/"
			end
		else if mentity isa MMethod and compiler.modelbuilder.toolcontext.opt_guard_call.value then
			var callsym = "CALL_" + const_color
			self.require_declaration(callsym)
			self.add "if (!{callsym}) \{"
			self.require_declaration(const_color)
			self.add "{ress}(({runtime_function.c_funptrtype})({class_info(arguments.first)}->vft[{const_color}]))({ss}); /* {mmethod} on {arguments.first.inspect}*/"
			self.add "\} else \{"
			self.add "{ress}{callsym}({ss}); /* {mmethod} on {arguments.first.inspect}*/"
			self.add "\}"
		else if mentity isa MMethod and compiler.modelbuilder.toolcontext.opt_trampoline_call.value then
			var callsym = "CALL_" + const_color
			self.require_declaration(callsym)
			self.add "{ress}{callsym}({ss}); /* {mmethod} on {arguments.first.inspect}*/"
		else
			self.require_declaration(const_color)
			self.add "{ress}(({runtime_function.c_funptrtype})({class_info(arguments.first)}->vft[{const_color}]))({ss}); /* {mmethod} on {arguments.first.inspect}*/"
		end

		if res0 != null then
			assert res != null
			assign(res0,res)
			res = res0
		end

		self.add("\}") # closes the null case

		return res
	end

	redef fun call(mmethoddef, recvtype, arguments)
	do
		assert arguments.length == mmethoddef.msignature.arity + 1 else debug("Invalid arity for {mmethoddef}. {arguments.length} arguments given.")

		var res: nullable RuntimeVariable
		var ret = mmethoddef.msignature.return_mtype
		if ret == null then
			res = null
		else
			ret = ret.resolve_for(mmethoddef.mclassdef.bound_mtype, mmethoddef.mclassdef.bound_mtype, mmethoddef.mclassdef.mmodule, true)
			res = self.new_var(ret)
		end

		if (mmethoddef.is_intern and not compiler.modelbuilder.toolcontext.opt_no_inline_intern.value) or
			(compiler.modelbuilder.toolcontext.opt_inline_some_methods.value and mmethoddef.can_inline(self)) then
			compiler.modelbuilder.nb_invok_by_inline += 1
			if compiler.modelbuilder.toolcontext.opt_invocation_metrics.value then add("count_invoke_by_inline++;")
			var frame = new StaticFrame(self, mmethoddef, recvtype, arguments)
			frame.returnlabel = self.get_name("RET_LABEL")
			frame.returnvar = res
			var old_frame = self.frame
			self.frame = frame
			self.add("\{ /* Inline {mmethoddef} ({arguments.join(",")}) on {arguments.first.inspect} */")
			mmethoddef.compile_inside_to_c(self, arguments)
			self.add("{frame.returnlabel.as(not null)}:(void)0;")
			self.add("\}")
			self.frame = old_frame
			return res
		end
		compiler.modelbuilder.nb_invok_by_direct += 1
		if compiler.modelbuilder.toolcontext.opt_invocation_metrics.value then add("count_invoke_by_direct++;")

		# Autobox arguments
		self.adapt_signature(mmethoddef, arguments)

		self.require_declaration(mmethoddef.c_name)
		if res == null then
			self.add("{mmethoddef.c_name}({arguments.join(", ")}); /* Direct call {mmethoddef} on {arguments.first.inspect}*/")
			return null
		else
			self.add("{res} = {mmethoddef.c_name}({arguments.join(", ")});")
		end

		return res
	end

	redef fun supercall(m: MMethodDef, recvtype: MClassType, arguments: Array[RuntimeVariable]): nullable RuntimeVariable
	do
		if arguments.first.mcasttype.ctype != "val*" then
			# In order to shortcut the primitive, we need to find the most specific method
			# However, because of performance (no flattening), we always work on the realmainmodule
			var main = self.compiler.mainmodule
			self.compiler.mainmodule = self.compiler.realmainmodule
			var res = self.monomorphic_super_send(m, recvtype, arguments)
			self.compiler.mainmodule = main
			return res
		end
		return table_send(m.mproperty, arguments, m)
	end

	redef fun vararg_instance(mpropdef, recv, varargs, elttype)
	do
		# A vararg must be stored into an new array
		# The trick is that the dymaic type of the array may depends on the receiver
		# of the method (ie recv) if the static type is unresolved
		# This is more complex than usual because the unresolved type must not be resolved
		# with the current receiver (ie self).
		# Therefore to isolate the resolution from self, a local StaticFrame is created.
		# One can see this implementation as an inlined method of the receiver whose only
		# job is to allocate the array
		var old_frame = self.frame
		var frame = new StaticFrame(self, mpropdef, mpropdef.mclassdef.bound_mtype, [recv])
		self.frame = frame
		#print "required Array[{elttype}] for recv {recv.inspect}. bound=Array[{self.resolve_for(elttype, recv)}]. selfvar={frame.arguments.first.inspect}"
		var res = self.array_instance(varargs, elttype)
		self.frame = old_frame
		return res
	end

	redef fun isset_attribute(a, recv)
	do
		self.check_recv_notnull(recv)
		var res = self.new_var(bool_type)

		# What is the declared type of the attribute?
		var mtype = a.intro.static_mtype.as(not null)
		var intromclassdef = a.intro.mclassdef
		mtype = mtype.resolve_for(intromclassdef.bound_mtype, intromclassdef.bound_mtype, intromclassdef.mmodule, true)

		if mtype isa MNullableType then
			self.add("{res} = 1; /* easy isset: {a} on {recv.inspect} */")
			return res
		end

		self.require_declaration(a.const_color)
		if self.compiler.modelbuilder.toolcontext.opt_no_union_attribute.value then
			self.add("{res} = {recv}->attrs[{a.const_color}] != NULL; /* {a} on {recv.inspect}*/")
		else

			if mtype.ctype == "val*" then
				self.add("{res} = {recv}->attrs[{a.const_color}].val != NULL; /* {a} on {recv.inspect} */")
			else
				self.add("{res} = 1; /* NOT YET IMPLEMENTED: isset of primitives: {a} on {recv.inspect} */")
			end
		end
		return res
	end

	redef fun read_attribute(a, recv)
	do
		self.check_recv_notnull(recv)

		# What is the declared type of the attribute?
		var ret = a.intro.static_mtype.as(not null)
		var intromclassdef = a.intro.mclassdef
		ret = ret.resolve_for(intromclassdef.bound_mtype, intromclassdef.bound_mtype, intromclassdef.mmodule, true)

		if self.compiler.modelbuilder.toolcontext.opt_isset_checks_metrics.value then
			self.compiler.attr_read_count += 1
			self.add("count_attr_reads++;")
		end

		self.require_declaration(a.const_color)
		if self.compiler.modelbuilder.toolcontext.opt_no_union_attribute.value then
			# Get the attribute or a box (ie. always a val*)
			var cret = self.object_type.as_nullable
			var res = self.new_var(cret)
			res.mcasttype = ret

			self.add("{res} = {recv}->attrs[{a.const_color}]; /* {a} on {recv.inspect} */")

			# Check for Uninitialized attribute
			if not ret isa MNullableType and not self.compiler.modelbuilder.toolcontext.opt_no_check_attr_isset.value then
				self.add("if (unlikely({res} == NULL)) \{")
				self.add_abort("Uninitialized attribute {a.name}")
				self.add("\}")

				if self.compiler.modelbuilder.toolcontext.opt_isset_checks_metrics.value then
					self.compiler.isset_checks_count += 1
					self.add("count_isset_checks++;")
				end
			end

			# Return the attribute or its unboxed version
			# Note: it is mandatory since we reuse the box on write, we do not whant that the box escapes
			return self.autobox(res, ret)
		else
			var res = self.new_var(ret)
			self.add("{res} = {recv}->attrs[{a.const_color}].{ret.ctypename}; /* {a} on {recv.inspect} */")

			# Check for Uninitialized attribute
			if ret.ctype == "val*" and not ret isa MNullableType and not self.compiler.modelbuilder.toolcontext.opt_no_check_attr_isset.value then
				self.add("if (unlikely({res} == NULL)) \{")
				self.add_abort("Uninitialized attribute {a.name}")
				self.add("\}")
				if self.compiler.modelbuilder.toolcontext.opt_isset_checks_metrics.value then
					self.compiler.isset_checks_count += 1
					self.add("count_isset_checks++;")
				end
			end

			return res
		end
	end

	redef fun write_attribute(a, recv, value)
	do
		self.check_recv_notnull(recv)

		# What is the declared type of the attribute?
		var mtype = a.intro.static_mtype.as(not null)
		var intromclassdef = a.intro.mclassdef
		mtype = mtype.resolve_for(intromclassdef.bound_mtype, intromclassdef.bound_mtype, intromclassdef.mmodule, true)

		# Adapt the value to the declared type
		value = self.autobox(value, mtype)

		self.require_declaration(a.const_color)
		if self.compiler.modelbuilder.toolcontext.opt_no_union_attribute.value then
			var attr = "{recv}->attrs[{a.const_color}]"
			if mtype.ctype != "val*" then
				assert mtype isa MClassType
				# The attribute is primitive, thus we store it in a box
				# The trick is to create the box the first time then resuse the box
				self.add("if ({attr} != NULL) \{")
				self.add("((struct instance_{mtype.c_name}*){attr})->value = {value}; /* {a} on {recv.inspect} */")
				self.add("\} else \{")
				value = self.autobox(value, self.object_type.as_nullable)
				self.add("{attr} = {value}; /* {a} on {recv.inspect} */")
				self.add("\}")
			else
				# The attribute is not primitive, thus store it direclty
				self.add("{attr} = {value}; /* {a} on {recv.inspect} */")
			end
		else
			self.add("{recv}->attrs[{a.const_color}].{mtype.ctypename} = {value}; /* {a} on {recv.inspect} */")
		end
	end

	# Check that mtype is a live open type
	fun hardening_live_open_type(mtype: MType)
	do
		if not compiler.modelbuilder.toolcontext.opt_hardening.value then return
		self.require_declaration(mtype.const_color)
		var col = mtype.const_color
		self.add("if({col} == -1) \{")
		self.add("PRINT_ERROR(\"Resolution of a dead open type: %s\\n\", \"{mtype.to_s.escape_to_c}\");")
		self.add_abort("open type dead")
		self.add("\}")
	end

	# Check that mtype it a pointer to a live cast type
	fun hardening_cast_type(t: String)
	do
		if not compiler.modelbuilder.toolcontext.opt_hardening.value then return
		add("if({t} == NULL) \{")
		add_abort("cast type null")
		add("\}")
		add("if({t}->id == -1 || {t}->color == -1) \{")
		add("PRINT_ERROR(\"Try to cast on a dead cast type: %s\\n\", {t}->name);")
		add_abort("cast type dead")
		add("\}")
	end

	redef fun init_instance(mtype)
	do
		self.require_declaration("NEW_{mtype.mclass.c_name}")
		var compiler = self.compiler
		if mtype isa MGenericType and mtype.need_anchor then
			hardening_live_open_type(mtype)
			link_unresolved_type(self.frame.mpropdef.mclassdef, mtype)
			var recv = self.frame.arguments.first
			var recv_type_info = self.type_info(recv)
			self.require_declaration(mtype.const_color)
			return self.new_expr("NEW_{mtype.mclass.c_name}({recv_type_info}->resolution_table->types[{mtype.const_color}])", mtype)
		end
		compiler.undead_types.add(mtype)
		self.require_declaration("type_{mtype.c_name}")
		return self.new_expr("NEW_{mtype.mclass.c_name}(&type_{mtype.c_name})", mtype)
	end

	redef fun type_test(value, mtype, tag)
	do
		self.add("/* {value.inspect} isa {mtype} */")
		var compiler = self.compiler

		var recv = self.frame.arguments.first
		var recv_type_info = self.type_info(recv)

		var res = self.new_var(bool_type)

		var cltype = self.get_name("cltype")
		self.add_decl("int {cltype};")
		var idtype = self.get_name("idtype")
		self.add_decl("int {idtype};")

		var maybe_null = self.maybe_null(value)
		var accept_null = "0"
		var ntype = mtype
		if ntype isa MNullableType then
			ntype = ntype.mtype
			accept_null = "1"
		end

		if value.mcasttype.is_subtype(self.frame.mpropdef.mclassdef.mmodule, self.frame.mpropdef.mclassdef.bound_mtype, mtype) then
			self.add("{res} = 1; /* easy {value.inspect} isa {mtype}*/")
			if compiler.modelbuilder.toolcontext.opt_typing_test_metrics.value then
				self.compiler.count_type_test_skipped[tag] += 1
				self.add("count_type_test_skipped_{tag}++;")
			end
			return res
		end

		if ntype.need_anchor then
			var type_struct = self.get_name("type_struct")
			self.add_decl("const struct type* {type_struct};")

			# Either with resolution_table with a direct resolution
			hardening_live_open_type(mtype)
			link_unresolved_type(self.frame.mpropdef.mclassdef, mtype)
			self.require_declaration(mtype.const_color)
			self.add("{type_struct} = {recv_type_info}->resolution_table->types[{mtype.const_color}];")
			if compiler.modelbuilder.toolcontext.opt_typing_test_metrics.value then
				self.compiler.count_type_test_unresolved[tag] += 1
				self.add("count_type_test_unresolved_{tag}++;")
			end
			hardening_cast_type(type_struct)
			self.add("{cltype} = {type_struct}->color;")
			self.add("{idtype} = {type_struct}->id;")
			if maybe_null and accept_null == "0" then
				var is_nullable = self.get_name("is_nullable")
				self.add_decl("short int {is_nullable};")
				self.add("{is_nullable} = {type_struct}->is_nullable;")
				accept_null = is_nullable.to_s
			end
		else if ntype isa MClassType then
			compiler.undead_types.add(mtype)
			self.require_declaration("type_{mtype.c_name}")
			hardening_cast_type("(&type_{mtype.c_name})")
			self.add("{cltype} = type_{mtype.c_name}.color;")
			self.add("{idtype} = type_{mtype.c_name}.id;")
			if compiler.modelbuilder.toolcontext.opt_typing_test_metrics.value then
				self.compiler.count_type_test_resolved[tag] += 1
				self.add("count_type_test_resolved_{tag}++;")
			end
		else
			self.add("PRINT_ERROR(\"NOT YET IMPLEMENTED: type_test(%s, {mtype}).\\n\", \"{value.inspect}\"); show_backtrace(1);")
		end

		# check color is in table
		if maybe_null then
			self.add("if({value} == NULL) \{")
			self.add("{res} = {accept_null};")
			self.add("\} else \{")
		end
		var value_type_info = self.type_info(value)
		self.add("if({cltype} >= {value_type_info}->table_size) \{")
		self.add("{res} = 0;")
		self.add("\} else \{")
		self.add("{res} = {value_type_info}->type_table[{cltype}] == {idtype};")
		self.add("\}")
		if maybe_null then
			self.add("\}")
		end

		return res
	end

	redef fun is_same_type_test(value1, value2)
	do
		var res = self.new_var(bool_type)
		# Swap values to be symetric
		if value2.mtype.ctype != "val*" and value1.mtype.ctype == "val*" then
			var tmp = value1
			value1 = value2
			value2 = tmp
		end
		if value1.mtype.ctype != "val*" then
			if value2.mtype == value1.mtype then
				self.add("{res} = 1; /* is_same_type_test: compatible types {value1.mtype} vs. {value2.mtype} */")
			else if value2.mtype.ctype != "val*" then
				self.add("{res} = 0; /* is_same_type_test: incompatible types {value1.mtype} vs. {value2.mtype}*/")
			else
				var mtype1 = value1.mtype.as(MClassType)
				self.require_declaration("class_{mtype1.c_name}")
				self.add("{res} = ({value2} != NULL) && ({value2}->class == &class_{mtype1.c_name}); /* is_same_type_test */")
			end
		else
			self.add("{res} = ({value1} == {value2}) || ({value1} != NULL && {value2} != NULL && {class_info(value1)} == {class_info(value2)}); /* is_same_type_test */")
		end
		return res
	end

	redef fun class_name_string(value)
	do
		var res = self.get_name("var_class_name")
		self.add_decl("const char* {res};")
		if value.mtype.ctype == "val*" then
			self.add "{res} = {value} == NULL ? \"null\" : {type_info(value)}->name;"
		else if value.mtype isa MClassType and value.mtype.as(MClassType).mclass.kind == extern_kind and
			value.mtype.as(MClassType).name != "NativeString" then
			self.add "{res} = \"{value.mtype.as(MClassType).mclass}\";"
		else
			self.require_declaration("type_{value.mtype.c_name}")
			self.add "{res} = type_{value.mtype.c_name}.name;"
		end
		return res
	end

	redef fun equal_test(value1, value2)
	do
		var res = self.new_var(bool_type)
		if value2.mtype.ctype != "val*" and value1.mtype.ctype == "val*" then
			var tmp = value1
			value1 = value2
			value2 = tmp
		end
		if value1.mtype.ctype != "val*" then
			if value2.mtype == value1.mtype then
				self.add("{res} = {value1} == {value2};")
			else if value2.mtype.ctype != "val*" then
				self.add("{res} = 0; /* incompatible types {value1.mtype} vs. {value2.mtype}*/")
			else if value1.mtype.is_tagged then
				self.add("{res} = ({value2} != NULL) && ({self.autobox(value2, value1.mtype)} == {value1});")
			else
				var mtype1 = value1.mtype.as(MClassType)
				self.require_declaration("class_{mtype1.c_name}")
				self.add("{res} = ({value2} != NULL) && ({value2}->class == &class_{mtype1.c_name});")
				self.add("if ({res}) \{")
				self.add("{res} = ({self.autobox(value2, value1.mtype)} == {value1});")
				self.add("\}")
			end
			return res
		end
		var maybe_null = true
		var test = new Array[String]
		var t1 = value1.mcasttype
		if t1 isa MNullableType then
			test.add("{value1} != NULL")
			t1 = t1.mtype
		else
			maybe_null = false
		end
		var t2 = value2.mcasttype
		if t2 isa MNullableType then
			test.add("{value2} != NULL")
			t2 = t2.mtype
		else
			maybe_null = false
		end

		var incompatible = false
		var primitive
		if t1.ctype != "val*" then
			primitive = t1
			if t1 == t2 then
				# No need to compare class
			else if t2.ctype != "val*" then
				incompatible = true
			else if can_be_primitive(value2) then
				if t1.is_tagged then
					self.add("{res} = {value1} == {value2};")
					return res
				end
				if not compiler.modelbuilder.toolcontext.opt_no_tag_primitives.value then
					test.add("(!{extract_tag(value2)})")
				end
				test.add("{value1}->class == {value2}->class")
			else
				incompatible = true
			end
		else if t2.ctype != "val*" then
			primitive = t2
			if can_be_primitive(value1) then
				if t2.is_tagged then
					self.add("{res} = {value1} == {value2};")
					return res
				end
				if not compiler.modelbuilder.toolcontext.opt_no_tag_primitives.value then
					test.add("(!{extract_tag(value1)})")
				end
				test.add("{value1}->class == {value2}->class")
			else
				incompatible = true
			end
		else
			primitive = null
		end

		if incompatible then
			if maybe_null then
				self.add("{res} = {value1} == {value2}; /* incompatible types {t1} vs. {t2}; but may be NULL*/")
				return res
			else
				self.add("{res} = 0; /* incompatible types {t1} vs. {t2}; cannot be NULL */")
				return res
			end
		end
		if primitive != null then
			if primitive.is_tagged then
				self.add("{res} = {value1} == {value2};")
				return res
			end
			test.add("((struct instance_{primitive.c_name}*){value1})->value == ((struct instance_{primitive.c_name}*){value2})->value")
		else if can_be_primitive(value1) and can_be_primitive(value2) then
			if not compiler.modelbuilder.toolcontext.opt_no_tag_primitives.value then
				test.add("(!{extract_tag(value1)}) && (!{extract_tag(value2)})")
			end
			test.add("{value1}->class == {value2}->class")
			var s = new Array[String]
			for t, v in self.compiler.box_kinds do
				if t.mclass_type.is_tagged then continue
				s.add "({value1}->class->box_kind == {v} && ((struct instance_{t.c_name}*){value1})->value == ((struct instance_{t.c_name}*){value2})->value)"
			end
			if s.is_empty then
				self.add("{res} = {value1} == {value2};")
				return res
			end
			test.add("({s.join(" || ")})")
		else
			self.add("{res} = {value1} == {value2};")
			return res
		end
		self.add("{res} = {value1} == {value2} || ({test.join(" && ")});")
		return res
	end

	fun can_be_primitive(value: RuntimeVariable): Bool
	do
		var t = value.mcasttype.as_notnullable
		if not t isa MClassType then return false
		var k = t.mclass.kind
		return k == interface_kind or t.ctype != "val*"
	end

	fun maybe_null(value: RuntimeVariable): Bool
	do
		var t = value.mcasttype
		return t isa MNullableType or t isa MNullType
	end

	redef fun array_instance(array, elttype)
	do
		var nclass = self.get_class("NativeArray")
		var arrayclass = self.get_class("Array")
		var arraytype = arrayclass.get_mtype([elttype])
		var res = self.init_instance(arraytype)
		self.add("\{ /* {res} = array_instance Array[{elttype}] */")
		var length = self.int_instance(array.length)
		var nat = native_array_instance(elttype, length)
		for i in [0..array.length[ do
			var r = self.autobox(array[i], self.object_type)
			self.add("((struct instance_{nclass.c_name}*){nat})->values[{i}] = (val*) {r};")
		end
		self.send(self.get_property("with_native", arrayclass.intro.bound_mtype), [res, nat, length])
		self.add("\}")
		return res
	end

	redef fun native_array_instance(elttype: MType, length: RuntimeVariable): RuntimeVariable
	do
		var mtype = self.get_class("NativeArray").get_mtype([elttype])
		self.require_declaration("NEW_{mtype.mclass.c_name}")
		assert mtype isa MGenericType
		var compiler = self.compiler
		if mtype.need_anchor then
			hardening_live_open_type(mtype)
			link_unresolved_type(self.frame.mpropdef.mclassdef, mtype)
			var recv = self.frame.arguments.first
			var recv_type_info = self.type_info(recv)
			self.require_declaration(mtype.const_color)
			return self.new_expr("NEW_{mtype.mclass.c_name}({length}, {recv_type_info}->resolution_table->types[{mtype.const_color}])", mtype)
		end
		compiler.undead_types.add(mtype)
		self.require_declaration("type_{mtype.c_name}")
		return self.new_expr("NEW_{mtype.mclass.c_name}({length}, &type_{mtype.c_name})", mtype)
	end

	redef fun native_array_def(pname, ret_type, arguments)
	do
		var elttype = arguments.first.mtype
		var nclass = self.get_class("NativeArray")
		var recv = "((struct instance_{nclass.c_name}*){arguments[0]})->values"
		if pname == "[]" then
			# Because the objects are boxed, return the box to avoid unnecessary (or broken) unboxing/reboxing
			var res = self.new_expr("{recv}[{arguments[1]}]", compiler.mainmodule.object_type)
			res.mcasttype = ret_type.as(not null)
			self.ret(res)
			return
		else if pname == "[]=" then
			self.add("{recv}[{arguments[1]}]={arguments[2]};")
			return
		else if pname == "length" then
			self.ret(self.new_expr("((struct instance_{nclass.c_name}*){arguments[0]})->length", ret_type.as(not null)))
			return
		else if pname == "copy_to" then
			var recv1 = "((struct instance_{nclass.c_name}*){arguments[1]})->values"
			self.add("memmove({recv1}, {recv}, {arguments[2]}*sizeof({elttype.ctype}));")
			return
		end
	end

	redef fun calloc_array(ret_type, arguments)
	do
		var mclass = self.get_class("ArrayCapable")
		var ft = mclass.mparameters.first
		var res = self.native_array_instance(ft, arguments[1])
		self.ret(res)
	end

	fun link_unresolved_type(mclassdef: MClassDef, mtype: MType) do
		assert mtype.need_anchor
		var compiler = self.compiler
		if not compiler.live_unresolved_types.has_key(self.frame.mpropdef.mclassdef) then
			compiler.live_unresolved_types[self.frame.mpropdef.mclassdef] = new HashSet[MType]
		end
		compiler.live_unresolved_types[self.frame.mpropdef.mclassdef].add(mtype)
	end
end

redef class MMethodDef
	# The C function associated to a mmethoddef
	fun separate_runtime_function: SeparateRuntimeFunction
	do
		var res = self.separate_runtime_function_cache
		if res == null then
			var recv = mclassdef.bound_mtype
			var msignature = msignature.resolve_for(recv, recv, mclassdef.mmodule, true)
			res = new SeparateRuntimeFunction(self, recv, msignature, c_name)
			self.separate_runtime_function_cache = res
		end
		return res
	end
	private var separate_runtime_function_cache: nullable SeparateRuntimeFunction

	# The C function associated to a mmethoddef, that can be stored into a VFT of a class
	# The first parameter (the reciever) is always typed by val* in order to accept an object value
	# The C-signature is always compatible with the intro
	fun virtual_runtime_function: SeparateRuntimeFunction
	do
		var res = self.virtual_runtime_function_cache
		if res == null then
			# Because the function is virtual, the signature must match the one of the original class
			var intromclassdef = mproperty.intro.mclassdef
			var recv = intromclassdef.bound_mtype

			res = separate_runtime_function
			if res.called_recv == recv then
				self.virtual_runtime_function_cache = res
				return res
			end

			var msignature = mproperty.intro.msignature.resolve_for(recv, recv, intromclassdef.mmodule, true)

			if recv.ctype == res.called_recv.ctype and msignature.c_equiv(res.called_signature) then
				self.virtual_runtime_function_cache = res
				return res
			end

			res = new SeparateRuntimeFunction(self, recv, msignature, "VIRTUAL_{c_name}")
			self.virtual_runtime_function_cache = res
			res.is_thunk = true
		end
		return res
	end
	private var virtual_runtime_function_cache: nullable SeparateRuntimeFunction
end

redef class MSignature
	# Does the C-version of `self` the same than the C-version of `other`?
	fun c_equiv(other: MSignature): Bool
	do
		if self == other then return true
		if arity != other.arity then return false
		for i in [0..arity[ do
			if mparameters[i].mtype.ctype != other.mparameters[i].mtype.ctype then return false
		end
		if return_mtype != other.return_mtype then
			if return_mtype == null or other.return_mtype == null then return false
			if return_mtype.ctype != other.return_mtype.ctype then return false
		end
		return true
	end
end

# The C function associated to a methoddef separately compiled
class SeparateRuntimeFunction
	super AbstractRuntimeFunction

	# The call-side static receiver
	var called_recv: MType

	# The call-side static signature
	var called_signature: MSignature

	# The name on the compiled method
	redef var build_c_name: String

	# Statically call the original body instead
	var is_thunk = false

	redef fun to_s do return self.mmethoddef.to_s

	# The C return type (something or `void`)
	var c_ret: String is lazy do
		var ret = called_signature.return_mtype
		if ret != null then
			return ret.ctype
		else
			return "void"
		end
	end

	# The C signature (only the parmeter part)
	var c_sig: String is lazy do
		var sig = new FlatBuffer
		sig.append("({called_recv.ctype} self")
		for i in [0..called_signature.arity[ do
			var mtype = called_signature.mparameters[i].mtype
			if i == called_signature.vararg_rank then
				mtype = mmethoddef.mclassdef.mmodule.get_primitive_class("Array").get_mtype([mtype])
			end
			sig.append(", {mtype.ctype} p{i}")
		end
		sig.append(")")
		return sig.to_s
	end

	# The C type for the function pointer.
	var c_funptrtype: String is lazy do return "{c_ret}(*){c_sig}"

	# The arguments, as generated by `compile_to_c`
	private var arguments: Array[RuntimeVariable] is noinit

	redef fun compile_to_c(compiler)
	do
		var mmethoddef = self.mmethoddef

		var recv = self.mmethoddef.mclassdef.bound_mtype
		var v = compiler.new_visitor
		var selfvar = new RuntimeVariable("self", called_recv, recv)
		var arguments = new Array[RuntimeVariable]
		var frame = new StaticFrame(v, mmethoddef, recv, arguments)
		v.frame = frame

		var msignature = called_signature
		var ret = called_signature.return_mtype

		var sig = new FlatBuffer
		var comment = new FlatBuffer
		sig.append(c_ret)
		sig.append(" ")
		sig.append(self.c_name)
		sig.append(c_sig)
		comment.append("({selfvar}: {selfvar.mtype}")
		arguments.add(selfvar)
		for i in [0..msignature.arity[ do
			var mtype = msignature.mparameters[i].mtype
			if i == msignature.vararg_rank then
				mtype = v.get_class("Array").get_mtype([mtype])
			end
			comment.append(", {mtype}")
			var argvar = new RuntimeVariable("p{i}", mtype, mtype)
			arguments.add(argvar)
		end
		comment.append(")")
		if ret != null then
			comment.append(": {ret}")
		end
		compiler.provide_declaration(self.c_name, "{sig};")
		self.arguments = arguments.to_a

		v.add_decl("/* method {self} for {comment} */")
		v.add_decl("{sig} \{")
		if ret != null then
			frame.returnvar = v.new_var(ret)
		end
		frame.returnlabel = v.get_name("RET_LABEL")

		if is_thunk then
			var subret = v.call(mmethoddef, recv, arguments)
			if ret != null then
				assert subret != null
				v.assign(frame.returnvar.as(not null), subret)
			end
		else
			mmethoddef.compile_inside_to_c(v, arguments)
		end

		v.add("{frame.returnlabel.as(not null)}:;")
		if ret != null then
			v.add("return {frame.returnvar.as(not null)};")
		end
		v.add("\}")
		compiler.names[self.c_name] = "{mmethoddef.full_name} ({mmethoddef.location.file.filename}:{mmethoddef.location.line_start})"
	end

	# Compile the trampolines used to implement late-binding.
	#
	# See `opt_trampoline_call`.
	fun compile_trampolines(compiler: SeparateCompiler)
	do
		var recv = self.mmethoddef.mclassdef.bound_mtype
		var selfvar = arguments.first
		var ret = called_signature.return_mtype

		if mmethoddef.is_intro and recv.ctype == "val*" then
			var m = mmethoddef.mproperty
			var n2 = "CALL_" + m.const_color
			compiler.provide_declaration(n2, "{c_ret} {n2}{c_sig};")
			var v2 = compiler.new_visitor
			v2.add "{c_ret} {n2}{c_sig} \{"
			v2.require_declaration(m.const_color)
			var call = "(({c_funptrtype})({selfvar}->class->vft[{m.const_color}]))({arguments.join(", ")});"
			if ret != null then
				v2.add "return {call}"
			else
				v2.add call
			end

			v2.add "\}"

		end
		if mmethoddef.has_supercall and recv.ctype == "val*" then
			var m = mmethoddef
			var n2 = "CALL_" + m.const_color
			compiler.provide_declaration(n2, "{c_ret} {n2}{c_sig};")
			var v2 = compiler.new_visitor
			v2.add "{c_ret} {n2}{c_sig} \{"
			v2.require_declaration(m.const_color)
			var call = "(({c_funptrtype})({selfvar}->class->vft[{m.const_color}]))({arguments.join(", ")});"
			if ret != null then
				v2.add "return {call}"
			else
				v2.add call
			end

			v2.add "\}"
		end
	end
end

redef class MType
	# Are values of `self` tagged?
	# If false, it means that the type is not primitive, or is boxed.
	var is_tagged = false
end

redef class MEntity
	var const_color: String is lazy do return "COLOR_{c_name}"
end

interface PropertyLayoutElement end

redef class MProperty
	super PropertyLayoutElement
end

redef class MPropDef
	super PropertyLayoutElement
end

redef class AMethPropdef
	# The semi-global compilation does not support inlining calls to extern news
	redef fun can_inline
	do
		var m = mpropdef
		if m != null and m.mproperty.is_init and m.is_extern then return false
		return super
	end
end
