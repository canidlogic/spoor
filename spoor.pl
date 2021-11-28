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

# @@TODO:
sub check_role {
  # @@TODO:
  return 1;
}

# @@TODO:
sub check_date {
  # @@TODO:
  return 1;
}

# @@TODO:
sub esc_xml_text {
  # @@TODO:
  return $_[0];
}

# @@TODO:
sub esc_xml_att {
  # @@TODO:
  return $_[0];
}

# Generate the metadata section of the OPF file.
#
# The given reference must be to the content of the parsed <metadata>
# element, and this function assumes that fold_elements() has already
# been applied to it.
#
# A <dc:identifier> element is always included in the generated metadata
# section that has an element ID of "ebook_uid"
#
# Parameters:
#
#   1 - reference to parsed <metadata> element content
#
#   2 : string - the code for the language to declare
#
# Return:
#
#   string - the <metadata> section that should be placed in the OPF
#   file, including the <metadata> tags
#
sub gen_meta {
  # Should have exactly two arguments
  ($#_ == 1) or die "Wrong number of arguments, stopped";
  
  # Get arguments
  my $metadata  = shift;
  my $root_lang = shift;
  
  # Verify that metadata is an array ref
  (ref($metadata) eq 'ARRAY') or die "Wrong argument type, stopped";
  
  # Set language code type and check it
  $root_lang = "$root_lang";
  (check_language_code($root_lang)) or
    die "Invalid language code '$root_lang', stopped";
  
  # Now go through the metadata section and build a hash of the data in
  # the %md hash
  my %md;
  for my $e (@{$metadata}) {
    # Ignore if not a true element
    if ($e->{'type'} ne 'e') {
      next;
    }
    
    # Handle specific element, ignoring unidentified ones
    if ($e->{'name'} eq 'title') { # -----------------------------------
      # Only one title allowed
      (not exists $md{'title'}) or
        die "Multiple <title>s in XML metadata, stopped";
      
      # Must have a "text" attribute
      (exists $e->{'attrib'}->{'text'}) or
        die "<title> in XML metadata missing text prop, stopped";
      
      # Store title
      $md{'title'} = "$e->{'attrib'}->{'text'}";
      
    } elsif ($e->{'name'} eq 'creator') { # ----------------------------
      # Must have a "name" attribute
      (exists $e->{'attrib'}->{'name'}) or
        die "<creator> in XML metadata missing name prop, stopped";
      
      # If creator property not defined yet, set to empty array
      if (not exists $md{'creator'}) {
        $md{'creator'} = [];
      }
      
      # Create hashref for the new creator
      my $new_e = { name => "$e->{'attrib'}->{'name'}"};
      if (exists $e->{'attrib'}->{'role'}) {
        (check_role($e->{'attrib'}->{'role'})) or
          die "Invalid XML metadata person role: " .
              "'$e->{'attrib'}->{'role'}', stopped";
        $new_e->{'role'} = "$e->{'attrib'}->{'role'}";
      }
      if (exists $e->{'attrib'}->{'sort'}) {
        $new_e->{'sort'} = "$e->{'attrib'}->{'sort'}";
      }
      
      # Add the new creator
      push @{$md{'creator'}}, ($new_e);
      
    } elsif ($e->{'name'} eq 'description') { # ------------------------
      # Only one description allowed
      (not exists $md{'description'}) or
        die "Multiple <description>s in XML metadata, stopped";
      
      # Go through text content to build the full value
      my $full_str = '';
      for my $f (@{$e->{'content'}}) {
        # Verify that this is a text node
        ($f->{'type'} eq 't') or
          die "<description> in XML metadata may only " .
              "contain text, stopped";
        
        # Add content to full string
        $full_str = $full_str . "$f->{'content'}";
      }
      
      # Store description
      $md{'description'} = $full_str;
      
    } elsif ($e->{'name'} eq 'publisher') { # --------------------------
      # Only one publisher allowed
      (not exists $md{'publisher'}) or
        die "Multiple <publisher>s in XML metadata, stopped";
      
      # Must have a "name" attribute
      (exists $e->{'attrib'}->{'name'}) or
        die "<publisher> in XML metadata missing name prop, stopped";
      
      # Add the publisher
      $md{'publisher'} = "$e->{'attrib'}->{'name'}";
      
    } elsif ($e->{'name'} eq 'contributor') { # ------------------------
      # Must have a "name" attribute
      (exists $e->{'attrib'}->{'name'}) or
        die "<contributor> in XML metadata missing name prop, stopped";
      
      # If contributor property not defined yet, set to empty array
      if (not exists $md{'contributor'}) {
        $md{'contributor'} = [];
      }
      
      # Create hashref for the new contributor
      my $new_e = { name => "$e->{'attrib'}->{'name'}"};
      if (exists $e->{'attrib'}->{'role'}) {
        (check_role($e->{'attrib'}->{'role'})) or
          die "Invalid XML metadata person role: " .
              "'$e->{'attrib'}->{'role'}', stopped";
        $new_e->{'role'} = "$e->{'attrib'}->{'role'}";
      }
      if (exists $e->{'attrib'}->{'sort'}) {
        $new_e->{'sort'} = "$e->{'attrib'}->{'sort'}";
      }
      
      # Add the new contributor
      push @{$md{'contributor'}}, ($new_e);
      
    } elsif ($e->{'name'} eq 'date') { # -------------------------------
      # Must have an "event" and "value" attribute
      (exists $e->{'attrib'}->{'event'}) or
        die "<date> in XML metadata missing event prop, stopped";
      (exists $e->{'attrib'}->{'value'}) or
        die "<date> in XML metadata missing value prop, stopped";
      
      # Get the date type
      my $dtype = fc($e->{'attrib'}->{'event'});
      
      # Check the date type
      (($dtype eq 'creation') or
          ($dtype eq 'publication') or
          ($dtype eq 'modification')) or
        die "Unknown <date> event type '$dtype' " .
            "in XML metadata, stopped";
      
      # Make sure this particular date is not set yet
      (not exists $md{"date_$dtype"}) or
        die "Same <date> event type may not occur more than once " .
          " in XML metadata, stopped";
      
      # Get the date value
      my $dval = "$e->{'attrib'}->{'value'}";
      
      # Check the date format
      (check_date($dval)) or die "Invalid <date> '$dval' " .
        "in XML metadata, stopped";
      
      # Store the date value
      $md{"date_$dtype"} = $dval;
      
    } elsif ($e->{'name'} eq 'identifier') { # -------------------------
      # Only one identifier allowed
      (not exists $md{'identifier'}) or
        die "Multiple <identifier>s in XML metadata, stopped";
      
      # Must have a "scheme" and "value" attribute
      (exists $e->{'attrib'}->{'scheme'}) or
        die "<identifier> in XML metadata missing scheme prop, stopped";
      (exists $e->{'attrib'}->{'value'}) or
        die "<identifier> in XML metadata missing value prop, stopped";
      
      # Store as a hashref
      $md{'identifier'} = {
        scheme => "$e->{'attrib'}->{'scheme'}",
        value => "$e->{'attrib'}->{'value'}"
      };
      
    } elsif ($e->{'name'} eq 'rights') { # -----------------------------
      # Only one rights allowed
      (not exists $md{'rights'}) or
        die "Multiple <rights>s in XML metadata, stopped";
      
      # Go through text content to build the full value
      my $full_str = '';
      for my $f (@{$e->{'content'}}) {
        # Verify that this is a text node
        ($f->{'type'} eq 't') or
          die "<rights> in XML metadata may only contain text, stopped";
        
        # Add content to full string
        $full_str = $full_str . "$f->{'content'}";
      }
      
      # Store rights
      $md{'rights'} = $full_str;
    }
  }
  
  # Check that title and identifier are defined
  (exists $md{'title'}) or
    die "Missing <title> in XML metadata, stopped";
  (exists $md{'identifier'}) or
    die "Missing <identifier> in XML metadata, stopped";
  
  # Build the metadata section of the OPF file
  my $pval;
  my $meta_str = <<'EOD';
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:opf="http://www.idpf.org/2007/opf">
EOD
  
  # Add the <dc:title> element
  $pval = esc_xml_text($md{'title'});
  $meta_str = $meta_str . "    <dc:title>$md{'title'}</dc:title>\n";
  
  # Add any <dc:creator> elements
  if (exists $md{'creator'}) {
    for my $cr (@{$md{'creator'}}) {
      $meta_str = $meta_str . "    <dc:creator";
      if (exists $cr->{'sort'}) {
        $pval = esc_xml_att($cr->{'sort'});
        $meta_str = $meta_str . " opf:file-as=\"$pval\"";
      }
      if (exists $cr->{'role'}) {
        $pval = esc_xml_att($cr->{'role'});
        $meta_str = $meta_str . " opf:role=\"$pval\"";
      }
      $pval = esc_xml_text($cr->{'name'});
      $meta_str = $meta_str . ">$pval</dc:creator>\n";
    }
  }
  
  # Add the optional <dc:description> element
  if (exists $md{'description'}) {
    $pval = esc_xml_text($md{'description'});
    $meta_str = $meta_str
      . "    <dc:description>$pval</dc:description>\n";
  }
  
  # Add the optional <dc:publisher> element
  if (exists $md{'publisher'}) {
    $pval = esc_xml_text($md{'publisher'});
    $meta_str = $meta_str
      . "    <dc:publisher>$pval</dc:publisher>\n";
  }
  
  # Add any <dc:contributor> elements
  if (exists $md{'contributor'}) {
    for my $cr (@{$md{'contributor'}}) {
      $meta_str = $meta_str . "    <dc:contributor";
      if (exists $cr->{'sort'}) {
        $pval = esc_xml_att($cr->{'sort'});
        $meta_str = $meta_str . " opf:file-as=\"$pval\"";
      }
      if (exists $cr->{'role'}) {
        $pval = esc_xml_att($cr->{'role'});
        $meta_str = $meta_str . " opf:role=\"$pval\"";
      }
      $pval = esc_xml_text($cr->{'name'});
      $meta_str = $meta_str . ">$pval</dc:contributor>\n";
    }
  }
  
  # Add any <dc:date> elements
  if (exists $md{'date_creation'}) {
    $pval = esc_xml_text($md{'date_creation'});
    $meta_str = $meta_str . "    <dc:date opf:event=\"creation\">";
    $meta_str = $meta_str . "$pval</dc:date>\n";
  }
  
  if (exists $md{'date_publication'}) {
    $pval = esc_xml_text($md{'date_publication'});
    $meta_str = $meta_str . "    <dc:date opf:event=\"publication\">";
    $meta_str = $meta_str . "$pval</dc:date>\n";
  }
  
  if (exists $md{'date_modification'}) {
    $pval = esc_xml_text($md{'date_modification'});
    $meta_str = $meta_str . "    <dc:date opf:event=\"modification\">";
    $meta_str = $meta_str . "$pval</dc:date>\n";
  }
  
  # Add the <dc:identifier> element
  $pval = esc_xml_att($md{'identifier'}->{'scheme'});
  $meta_str = $meta_str . "    <dc:identifier id=\"ebook_uid\" "
                  . "opf:scheme=\"$pval\">";
  $pval = esc_xml_text($md{'identifier'}->{'value'});
  $meta_str = $meta_str . "$pval</dc:identifier>\n";
  
  # Add the <dc:language> element
  $pval = esc_xml_text($root_lang);
  $meta_str = $meta_str . "    <dc:language>$pval</dc:language>\n";
  
  # Add the optional <dc:rights> element
  if (exists $md{'rights'}) {
    $pval = esc_xml_text($md{'rights'});
    $meta_str = $meta_str
      . "    <dc:rights>$pval</dc:rights>\n";
  }
  
  # Finish the constructed metadata section
  $meta_str = $meta_str . "  </metadata>\n";
  
  # Return result
  return $meta_str;
}

# Generate the manifest section of the OPF file.
#
# The given reference must be to an array of paths to resource files
# that were passed on the command line.
#
# In addition to the resources present in the given array, this function
# will always generate a resource declaration for "content.html" with an
# XHTML type, and "toc.ncx" with an NCX type.
#
# All manifest items will be given XML element IDs.  "content.html"
# always has the ID "content" while "toc.ncx" always has the ID "ncx".
# All resources are given IDs of type "item#" where # is the index of
# the item in the passed array.  Note that the first item has ID "item0"
# rather than "item1".
#
# Parameters:
#
#   1 - array reference to paths of all the extra resource files that
#   were passed on the command line (may be empty)
#
# Return:
#
#   string - the <manifest> section that should be placed in the OPF
#   file, including the <manifest> tags
#
sub gen_manifest {
  # Should have exactly one arguments
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get the argument and check type
  my $ares = shift;
  (ref($ares) eq 'ARRAY') or die "Wrong argument type, stopped";
  
  # Build the manifest section of the OPF file
  my $mani_str = <<'EOD';
  <manifest>
    <item id="content" href="content.html"
        media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx"
        media-type="application/x-dtbncx+xml"/>
EOD
  
  # Declare any additional resources
  for(my $r = 0; $r < scalar @$ares; $r++) {
    
    # Get the filename of this resource
    my $fname;
    (undef, undef, $fname) = File::Spec->splitpath($ares->[$r]);
    
    # Determine the MIME type
    my $mime_type;
    if ($fname =~ /.css$/ui) {
      $mime_type = "text/css";
      
    } elsif ($fname =~ /.png$/ui) {
      $mime_type = "image/png";
      
    } elsif (($fname =~ /.jpg$/ui) || ($fname =~ /.jpeg$/ui)) {
      $mime_type = "image/jpeg";
      
    } elsif ($fname =~ /.svg$/ui) {
      $mime_type = "image/svg+xml";
      
    } else {
      die "Unrecognized resource file extension for '$fname', stopped";
    }
    
    # Declare resource
    $fname = esc_xml_att($fname);
    $mime_type = esc_xml_att($mime_type);
    
    $mani_str = $mani_str . "    <item id=\"item$r\" href=\"$fname\"\n";
    $mani_str = $mani_str . "        media-type=\"$mime_type\"/>\n";
  }
  
  # Finish the manifest section
  $mani_str = $mani_str . "  </manifest>\n";
  
  # Return the generated result
  return $mani_str;
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
#   2 : array ref - the paths to all resources that will be added to
#   this EPUB
#
# Return:
#
#   1 : string - the contents of the generated OPF file
#
#   2 : string - the contents of the generated NCX file
#
sub parse_xml {
  # Should have exactly two arguments
  ($#_ == 1) or die "Wrong number of arguments, stopped";
  
  # Get arguments and set/check type
  my $arg_path = shift;
  my $ares     = shift;
  
  $arg_path = "$arg_path";
  (ref($ares) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
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
        $metadata = $e->{'content'};
        $has_metadata = 1;
      } else {
        die "Multiple <metadata> sections in XML, stopped";
      }
      
    } elsif ($e->{'name'} eq 'nav') {
      # Found the nav section
      if ($has_nav == 0) {
        $nav = $e->{'content'};
        $has_nav = 1;
      } else {
        die "Multiple <nav> sections in XML, stopped";
      }
    }
  }
  
  # Make sure we found both sections
  ($has_metadata) or die "Missing <metadata> section in XML, stopped";
  ($has_nav) or die "Missing <nav> section in XML, stopped";
  
  # Build the metadata section
  my $meta_str = gen_meta($metadata, $root_lang);
  
  # Build the manifest section
  my $mani_str = gen_manifest($ares);
  
  # @@TODO:
  
  # Now put together the whole OPF file
  my $opf_text = <<EOD;
<?xml version="1.0"?>
<package
    version="2.0"
    xmlns="http://www.idpf.org/2007/opf"
    unique-identifier="ebook_uid">
$meta_str
$mani_str
  <spine toc="ncx">
    <itemref idref="content" linear="yes"/>
  </spine>
</package>

EOD
  
  # @@TODO:
  my $ncx_text = "NCX file";

  # @@TODO:
  return ($opf_text, $ncx_text);
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

($opf_text, $ncx_text) = parse_xml($arg_xml, \@arg_res);

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
