# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2012-2014 Alexis Laferrière <alexis.laf@xymus.net>
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

# This script extracts pngs from a single svg for all objects with ids
# beginning by 0. Requires Inkscape.
module svg_to_png_and_nit

import opts
import template

class Image
	var name: String
	var x: Int
	var y: Int
	var w: Int
	var h: Int
	fun right: Int do return x+w
	fun bottom: Int do return y+h

	redef fun to_s do return name
end

# The Nit source file to retreive all images
class ImageSetSrc
	super Template

	var name: String
	init(name: String) do self.name = name

	var attributes = new Array[String]
	var load_exprs = new Array[String]

	redef fun rendering
	do
		add """
# file generated by svg_to_png, do not modify, redef instead

import mnit::image_set

class {{{name}}}
	super ImageSet

"""
		add_all attributes
		add """

	redef fun load_all(app: App)
	do
"""
		add_all load_exprs
		add """
	end
end
"""
	end
end

redef class Int
	fun adapt(d: Int, scale: Float): Int
	do
		var corrected = self-d
		return (corrected.to_f*scale).to_i
	end

	fun next_pow2: Int
	do
		var p = 2
		while p < self do p = p*2
		return p
	end
end

var opt_out_src = new OptionString("Path to output source file", "--src", "-s")
var opt_assets = new OptionString("Path to assert dir where to put PNG files", "--assets", "-a")
var opt_scale = new OptionFloat("Apply scaling to exported images (defaut at 1.0 of 90dpi)", 1.0, "--scale", "-x")
var opt_help = new OptionBool("Print this help message", "--help", "-h")

var opt_context = new OptionContext
opt_context.add_option(opt_out_src, opt_assets, opt_scale, opt_help)

opt_context.parse(args)
var rest = opt_context.rest
var errors = opt_context.errors
if rest.is_empty and not opt_help.value then errors.add "You must specify at least one source drawing file"
if not errors.is_empty or opt_help.value then
	print errors.join("\n")
	print "Usage: svg_to_png_and_nit [Options] drawing.svg [Other files]"
	print "Options:"
	opt_context.usage
	exit 1
end

var drawings = rest
for drawing in drawings do
	if not drawing.file_exists then
		stderr.write "Source drawing file '{drawing}' does not exist."
		exit 1
	end
end

var assets_path = opt_assets.value
if assets_path == null then assets_path = "assets"
if not assets_path.file_exists then
	stderr.write "Assets dir '{assets_path}' does not exist (use --assets)\n"
	exit 1
end

var src_path = opt_out_src.value
if src_path == null then src_path = "src"
if not src_path.file_exists then
	stderr.write "Source dir '{src_path}' does not exist (use --src)\n"
	exit 1
end

var scale = opt_scale.value

var arrays_of_images = new Array[String]

for drawing in drawings do
	var drawing_name = drawing.basename(".svg")

	# Get the page dimensions
	# Inkscape doesn't give us this information
	var page_width = -1
	var page_height = -1
	var svg_file = new IFStream.open(drawing)
	while not svg_file.eof do
		var line = svg_file.read_line

		if page_width == -1 and line.search("width") != null then
			var words = line.split("=")
			var n = words[1]
			n = n.substring(1, n.length-2) # remove ""
			page_width = n.to_f.ceil.to_i
		else if page_height == -1 and line.search("height") != null then
			var words = line.split("=")
			var n = words[1]
			n = n.substring(1, n.length-2) # remove ""
			page_height = n.to_f.ceil.to_i
		end
	end
	svg_file.close

	assert page_width != -1
	assert page_height != -1

	# Query Inkscape
	var prog = "inkscape"
	var proc = new IProcess.from_a(prog, ["--without-gui", "--query-all", drawing])

	var min_x = 1000000
	var min_y = 1000000
	var max_x = -1
	var max_y = -1
	var images = new Array[Image]

	# Gather all images beginning with 0
	# also get the bounding box of all images
	while not proc.eof do
		var line = proc.read_line
		var words = line.split(",")
		
		if words.length == 5 then
			var id = words[0]

			var x = words[1].to_f.floor.to_i
			var y = words[2].to_f.floor.to_i
			var w = words[3].to_f.ceil.to_i
			var h = words[4].to_f.ceil.to_i

			if id.has_prefix("0") then
				var nit_name = id.substring_from(1)
				nit_name = nit_name.replace('-', "_")

				var image = new Image(nit_name, x, y, w, h)
				min_x = min_x.min(x)
				min_y = min_y.min(y)
				max_x = max_x.max(image.right)
				max_y = max_y.max(image.bottom)

				images.add image
			end
		end
	end
	proc.close

	# Nit class
	var nit_class_name = drawing_name.chars.first.to_s.to_upper + drawing_name.substring_from(1) + "Images"
	var nit_src = new ImageSetSrc(nit_class_name)
	nit_src.attributes.add "\tprivate var main_image: Image\n"
	nit_src.load_exprs.add "\t\tmain_image = app.load_image(\"images/{drawing_name}.png\")\n"

	# Sort images by name, it prevents Array errors and looks better
	alpha_comparator.sort(images)

	# Add images to Nit source file
	for image in images do
		# Adapt coordinates to new top left and scale
		var x = image.x.adapt(min_x, scale)
		var y = image.y.adapt(min_y, scale)
		var w = (image.w.to_f*scale).to_i
		var h = (image.h.to_f*scale).to_i

		var nit_name = image.name
		var last_char = nit_name.chars.last
		if last_char.to_s.is_numeric then
			# Array of images
			# TODO support more than 10 images in an array

			nit_name = nit_name.substring(0, nit_name.length-1)
			if not arrays_of_images.has(nit_name) then
				# Create class attribute to store Array
				arrays_of_images.add(nit_name)
				nit_src.attributes.add "\tvar {nit_name} = new Array[Image]\n"
			end
			nit_src.load_exprs.add "\t\t{nit_name}.add(main_image.subimage({x}, {y}, {w}, {h}))\n"
		else
			# Single image
			nit_src.attributes.add "\tvar {nit_name}: Image\n"
			nit_src.load_exprs.add "\t\t{nit_name} = main_image.subimage({x}, {y}, {w}, {h})\n"
		end
	end

	# Output source file
	var src_file = new OFStream.open("{src_path}/{drawing_name}.nit")
	nit_src.write_to(src_file)
	src_file.close

	# Find closest power of 2
	var dx = max_x - min_x
	max_x = dx.next_pow2 + min_x

	var dy = max_y - min_y
	max_y = dy.next_pow2 + min_y

	# Inkscape's --export-area inverts the Y axis. It uses the lower left corner of
	# the drawing area where as queries return coordinates from the top left.
	var y0 = page_height - max_y
	var y1 = page_height - min_y

	# Output png file to assets
	var png_path = "{assets_path}/images/{drawing_name}.png"
	var proc2 = new Process.from_a(prog, [drawing, "--without-gui",
		"--export-dpi={(90.0*scale).to_i}",
		"--export-png={png_path}",
		"--export-area={min_x}:{y0}:{max_x}:{y1}",
		"--export-background=#000000", "--export-background-opacity=0.0"])
	proc2.wait
end
