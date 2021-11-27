#!/usr/bin/env perl
use strict;
use feature 'fc';
use feature 'unicode_strings';
use warnings FATAL => "utf8";

# Non-core dependencies
use Archive::Zip qw( :ERROR_CODES :CONSTANTS);
use XML::Tiny qw(parsefile);

# Core dependencies
use File::Spec;

=head1 NAME

spoor.pl - Create an EPUB-2 E-Book.

=head1 SYNOPSIS

  spoor.pl out.epub source.html metadata.xml main.css img1.png img2.jpg

=head1 DESCRIPTION

This script compiles an EPUB-2 E-Book from an XHTML source file, an XML
metadata file in a special format, and zero or more style sheet and
image resources that will be embedded in the book.  See the README.md
file for further information.

=cut

# ===============
# Local functions
# ===============

# Check that a language code is valid.
#
# This simply checks that the given string is ASCII alphanumeric and
# hyphens, that there is at least one character, that neither the first
# nor last characters are hyphen, and that no two hyphens occur next to
# each other.
#
# Parameters:
#
#   1 : string - the language code to check
#
# Return:
#
#   1 if valid, 0 if not
#
sub check_language_code {
  # @@TODO:
  return 1;
}

# Recursively case-fold all element names and attribute names to
# lowercase in a parsed XML document.
#
# This also checks the basic XML format of the parsed document along the
# way.
#
# Parameters:
#
#   1 - reference to root of parsed XML document
#
#   2 : integer - one if this is the root element, zero if this is a
#   recursive invocation
#
sub fold_elements {
  # Should have exactly two arguments
  ($#_ == 1) or die "Wrong number of arguments, stopped";
  
  # Get arguments
  my $xf = shift;
  my $is_root = shift;
  
  # The parsed element should be an array reference
  (ref($xf) eq 'ARRAY') or
    die "Invalid XML structure, stopped";
  
  # If this is root, there should be exactly one element
  if ($is_root) {
    (scalar @{$xf} == 1) or
      die "Non-singular root XML node, stopped";
  }
  
  # Check each element
  for my $e (@{$xf}) {
    # Element should be hashref
    (ref($e) eq 'HASH') or
      die "Invalid XML element structure, stopped";
    
    # All elements must have type and content properties
    (exists $e->{'type'}) or
      die "XML parsed element missing type, stopped";
    (exists $e->{'content'}) or
      die "XML parsed element missing content, stopped";
    
    # Type must be "e" or "t"
    (($e->{'type'} eq 'e') or ($e->{'type'} eq 't')) or
      die "XML parsed element has invalid type, stopped";
    
    # Further checking dependent on type
    if ($e->{'type'} eq 'e') {
      # For true element, we must also have name and attrib keys
      (exists $e->{'name'}) or
        die "XML parsed element missing name, stopped";
      (exists $e->{'attrib'}) or
        die "XML parsed element missing attrib, stopped";
      
      # Name must be a scalar
      (not ref $e->{'name'}) or
        die "XML parsed element has wrong name format, stopped";
      
      # Case-fold name
      $e->{'name'} = fc($e->{'name'});
      
      # Attrib must be a hashref
      (ref($e->{'attrib'}) eq 'HASH') or
        die "XML parsed element has wrong attrib format, stopped";
      
      # Get all attribute keys
      my @akeys = keys %{$e->{'attrib'}};
      
      # Case-fold keys
      for my $ak (@akeys) {
        my $folded_key = fc($ak);
        if ($folded_key ne $ak) {
          my $v = $e->{'attrib'}->{$ak};
          delete $e->{'attrib'}->{$ak};
          $e->{'attrib'}->{$folded_key} = $v;
        }
      }
      
      # Check that all attribute values are scalar
      for my $v (values %{$e->{'attrib'}}) {
        (not ref $v) or die "Non-scalar attribute value, stopped";
      }
      
      # Recursively check and fold content
      fold_elements($e->{'content'}, 0);
      
    } elsif ($e->{'type'} eq 't') {
      # For text element, content must be scalar
      (not ref $e->{'content'}) or
        die "Parsed XML text element has wrong content, stopped";
      
    } else {
      die "Unexpected, stopped";
    }
  }
}

# Parse the XML metadata file and use it to generate the OPF file and
# the NCX file.
#
# Parameters:
#
#   1 : string - the path to the XML metadata file
#
# Return:
#
#   1 : string - the contents of the generated OPF file
#
#   2 : string - the contents of the generated NCX file
#
sub parse_xml {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $arg_path = shift;
  $arg_path = "$arg_path";
  
  # Open XML file for reading in UTF-8
  open(my $xml_fh, "< :encoding(utf8)", $arg_path) or
    die "Failed to open XML file '$arg_path', stopped";
  
  # Parse the XML file
  my $xf = parsefile($xml_fh);
  (defined $xf) or die "Failed to parse XML file, stopped";
  
  # Close the XML file
  close($xml_fh);
  
  # Visit all nodes and case-fold their names and all their attribute
  # names to lowercase, checking parsed format along the way
  fold_elements($xf, 1);
  
  # Root element must be <spoor>
  (($xf->[0]->{'type'} eq 'e') and
      ($xf->[0]->{'name'} eq 'spoor')) or
    die "XML file has wrong root element, stopped";
  
  # Root element must have xml:lang and format attributes
  ((exists $xf->[0]->{'attrib'}->{'xml:lang'}) and
      (exists $xf->[0]->{'attrib'}->{'format'})) or
    die "Root XML element must have xml:lang and format props, stopped";
  
  # Format must be html
  ($xf->[0]->{'attrib'}->{'format'} =~ /^html$/ui) or
    die "Unsupported Spoor format in XML file, stopped";
  
  # Get the root language
  my $root_lang = $xf->[0]->{'attrib'}->{'xml:lang'};
  $root_lang = "$root_lang";
  
  # Make language tag is valid
  (check_language_code($root_lang)) or
    die "Language code '$root_lang' in XML is invalid, stopped";
  
  # Now go through the content array and find the single metadata and
  # nav sections
  my $has_metadata = 0;
  my $has_nav = 0;
  
  my $metadata;
  my $nav;
  
  for my $e (@{$xf->[0]->{'content'}}) {
    # Ignore if not a true element
    if ($e->{'type'} ne 'e') {
      next;
    }
    
    # Look for desired elements
    if ($e->{'name'} eq 'metadata') {
      # Found the metadata section
      if ($has_metadata == 0) {
        $metadata = $e;
        $has_metadata = 1;
      } else {
        die "Multiple <metadata> sections in XML, stopped";
      }
      
    } elsif ($e->{'name'} eq 'nav') {
      # Found the nav section
      if ($has_nav == 0) {
        $nav = $e;
        $has_nav = 1;
      } else {
        die "Multiple <nav> sections in XML, stopped";
      }
    }
  }
  
  # Make sure we found both sections
  ($has_metadata) or die "Missing <metadata> section in XML, stopped";
  ($has_nav) or die "Missing <nav> section in XML, stopped";
  
  # @@TODO:
  return ("OPF file\n", "NCX file \n");
}

# ==================
# Program entrypoint
# ==================

# Must have at least three arguments
#
($#ARGV >= 2) or die "Not enough program arguments, stopped";

# Get the arguments
#
my $arg_out  = $ARGV[0];
my $arg_html = $ARGV[1];
my $arg_xml  = $ARGV[2];

my @arg_res;
if ($#ARGV > 2) {
  push @arg_res, @ARGV[3 .. $#ARGV];
}

# Make sure everything besides the output file is an existing regular
# file
#
(-f $arg_html) or die "Can't find file '$arg_html', stopped";
(-f $arg_xml) or die "Can't find file '$arg_xml', stopped";
for my $p (@arg_res) {
  (-f $p) or die "Can't find file '$p', stopped";
}

# Check the filename of each resource file and verify uniqueness
#
my %rn;
for my $p (@arg_res) {
  
  # Get the filename
  my $fname;
  (undef, undef, $fname) = File::Spec->splitpath($p);
  
  # Check length
  ((length $fname > 0) and (length $fname < 255)) or
    die "File name '$fname' is empty or too long, stopped";
  
  # Check format
  ($fname =~ /^([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)$/u) or
    die "File name '$fname' has invalid format, stopped";
  
  my $fname_name = $1;
  my $fname_ext = $2;
  
  # Check that extension is supported
  (($fname_ext =~ /^css$/ui) or
      ($fname_ext =~ /^png$/ui) or
      ($fname_ext =~ /^jpg$/ui) or
      ($fname_ext =~ /^jpeg$/ui) or
      ($fname_ext =~ /^svg$/ui)) or
    die "File name '$fname' has unsupported extension, stopped";
  
  # Check that name is not a special DOS device
  ((not ($fname_name =~ /^AUX$/ui)) and
      (not ($fname_name =~ /^COM[1-9]$/ui)) and
      (not ($fname_name =~ /^CON$/ui)) and
      (not ($fname_name =~ /^LPT[1-9]$/ui)) and
      (not ($fname_name =~ /^NUL$/ui)) and
      (not ($fname_name =~ /^PRN$/ui))) or
    die "File name '$fname' contains DOS device name, stopped";
  
  # Get a lowercase version of the filename, check whether it has
  # already been used, and then add it to the index
  my $fname_key = lc($fname);
  (not (exists $rn{$fname_key})) or
    die "Resource filename '$fname' used multiple times, stopped";
  $rn{$fname_key} = $fname;
}

# Create the ZIP file object
#
my $zip = Archive::Zip->new();

# First off, we need to add a mimetype file declaring the file type
#
$zip->addString('application/epub+zip', 'mimetype');

# Next, we need the META-INF directory
#
$zip->addDirectory('META-INF');

# Within the META-INF directory, we need the container.xml file; this
# file will point to the content.opf file that we will have in the OEBPS
# directory
#
my $str_container = <<'EOD';
<?xml version="1.0"?>
<container version="1.0"
    xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
        media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>

EOD

$zip->addString($str_container, 'META-INF/container.xml');

# Now create the OEBPS directory that will hold the book content
#
$zip->addDirectory('OEBPS');

# Generate the OPF and NCX files from the XML metadata file
#
my $opf_text;
my $ncx_text;

($opf_text, $ncx_text) = parse_xml($arg_xml);

# Add the OPF and NCX files
#
$zip->addString($opf_text, 'OEBPS/content.opf');
$zip->addString($ncx_text, 'OEBPS/toc.ncx');

# Transfer the XHTML file into the OEBPS directory, renaming it
# content.html
#
$zip->addFile($arg_html, 'OEBPS/content.html');

# Transfer all resource files into the OEBPS directory, keeping their
# names but not their directory trees; also, for PNG and JPEG files, do
# not add additional compression in the Zip file since these files are
# already compressed
#
for my $p (@arg_res) {
  
  # Get the filename
  my $fname;
  (undef, undef, $fname) = File::Spec->splitpath($p);
  
  # Check whether compression is needed in the Zip file for this file
  my $needs_compress = 1;
  if (($fname =~ /.png$/ui) or
        ($fname =~ /.jpg$/ui) or
        ($fname =~ /.jpeg$/ui)) {
    $needs_compress = 0;
  }
  
  # Add the file to the directory
  if ($needs_compress) {
    $zip->addFile($p, "OEBPS/$fname");
  } else {
    $zip->addFile($p, "OEBPS/$fname", COMPRESSION_LEVEL_NONE);
  }
}

# Write the completed ZIP file to disk
#
unless ($zip->writeToFileNamed($arg_out) == AZ_OK) {
  die "Failed to write ZIP archive, stopped";
}

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
