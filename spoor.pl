#!/usr/bin/env perl
use strict;
use feature 'fc';
use feature 'unicode_strings';
use warnings FATAL => "utf8";

# Non-core dependencies
use Archive::Zip qw( :ERROR_CODES :CONSTANTS);
use XML::Tiny qw(parsefile);

# Core dependencies
use Encode qw(encode);
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

# =========
# Constants
# =========

# Hash that maps all recognized person roles to the value one.
#
# All roles given here are in lowercase.
#
my %role_codes = (
  adp => 1,
  ann => 1,
  arr => 1,
  art => 1,
  asn => 1,
  aut => 1,
  aqt => 1,
  aft => 1,
  aui => 1,
  ant => 1,
  bkp => 1,
  clb => 1,
  cmm => 1,
  dsr => 1,
  edt => 1,
  ill => 1,
  lyr => 1,
  mdc => 1,
  mus => 1,
  nrt => 1,
  oth => 1,
  pht => 1,
  prt => 1,
  red => 1,
  rev => 1,
  spn => 1,
  ths => 1,
  trc => 1,
  trl => 1
);

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
# This is not a full verification that the language code is fully valid,
# just a basic syntax check.
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
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Valid flag starts set
  my $valid = 1;
  
  # Fail if string is not sequence of one or more ASCII alphanumerics
  # and hyphens
  unless ($str =~ /^[A-Za-z0-9\-]+$/u) {
    $valid = 0;
  }
  
  # Fail if first or last character is hyphen
  if ($valid) {
    if (($str =~ /^\-/u) or ($str =~ /\-$/u)) {
      $valid = 0;
    }
  }
  
  # Fail if two hyphens in a row
  if ($valid) {
    if ($str =~ /\-\-/u) {
      $valid = 0;
    }
  }
  
  # Return validity
  return $valid;
}

# Check that the role for a creator or contributor declaration is valid.
#
# The role must be exactly three ASCII letters and must be a
# case-insensitive match for one of the recognized role codes.
#
# Parameters:
#
#   1 : string - the role code to check
#
# Return:
#
#   1 if valid, 0 if not
#
sub check_role {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Valid flag starts set
  my $valid = 1;
  
  # Fail if string is not sequence of exactly three ASCII letters
  unless ($str =~ /^[A-Za-z]{3}$/u) {
    $valid = 0;
  }
  
  # Fail unless lowercase version of role is in role map
  if ($valid) {
    unless (exists $role_codes{lc($str)}) {
      $valid = 0;
    }
  }
  
  # Return validity
  return $valid;
}

# Check that the given date string is valid.
#
# The date must be either in YYYY or YYYY-MM or YYYY-MM-DD format.  This
# function will also verify that the field values make sense.  The
# earliest supported date is 1582-10-15 (or 1582-10 or 1582) and the
# latest supported date is 9999-12-31.
#
# Parameters:
#
#   1 : string - the date string to check
#
# Return:
#
#   1 if valid, 0 if not
#
sub check_date {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Valid flag starts set
  my $valid = 1;
  
  # Checking depends on the specific format
  if ($str =~ /^([0-9]{4})\-([0-9]{2})\-([0-9]{2})$/u) {
    # Year, month, day -- get integer values
    my $y = int($1);
    my $m = int($2);
    my $d = int($3);
    
    # Check year in range [1582, 9999]
    unless (($y >= 1582) and ($y <= 9999)) {
      $valid = 0;
    }
    
    # For all years but 1582, check that month in range 1-12; for 1582,
    # check that month in range 10-12
    if ($valid) {
      if ($y == 1582) {
        unless (($m >= 10) and ($m <= 12)) {
          $valid = 0;
        }
        
      } else {
        unless (($m >= 1) and ($m <= 12)) {
          $valid = 0;
        }
      }
    }
    
    # For all year/month combinations except 1582-10, check that day of
    # month is at least one; for 1582-10, check that day is at least 15
    if ($valid) {
      if (($y == 1582) and ($m == 10)) {
        unless ($d >= 15) {
          $valid = 0;
        }
        
      } else {
        unless ($d >= 1) {
          $valid = 0;
        }
      }
    }
    
    # Check the upper limit of day depending on specific month and
    # whether there is a leap year
    if ($valid) {
      if (($m == 11) or ($m == 4) or ($m == 6) or ($m == 9)) {
        # November, April, June, September have 30 days
        unless ($d <= 30) {
          $valid = 0;
        }
        
      } elsif ($m == 2) {
        # February depends on whether there is a leap year -- check
        # whether this is a leap year
        my $is_leap = 0;
        if (($y % 4) == 0) {
          # Year divisible by four
          if (($y % 100) == 0) {
            # Year divisible by four and 100
            if (($y % 400) == 0) {
              # Year divisible by four and 100 and 400, so leap year
              $is_leap = 1;
              
            } else {
              # Year divisible by four and 100 but not 400, so not leap
              # year
              $is_leap = 0;
            }
            
          } else {
            # Year divisible by four but not by 100, so leap year
            $is_leap = 1;
          }
          
        } else {
          # Year not divisible by four, so not a leap year
          $is_leap = 0;
        }
        
        # Check day limit depending on leap year
        if ($is_leap) {
          unless ($d <= 29) {
            $valid = 0;
          }
          
        } else {
          unless ($d <= 28) {
            $valid = 0;
          }
        }
        
      } else {
        # All other months have 31 days
        unless ($d <= 31) {
          $valid = 0;
        }
      }
    }
    
  } elsif ($str =~ /^([0-9]{4})\-([0-9]{2})$/u) {
    # Year and month -- get integer values
    my $y = int($1);
    my $m = int($2);
    
    # Check year in range [1582, 9999]
    unless (($y >= 1582) and ($y <= 9999)) {
      $valid = 0;
    }
    
    # For all years but 1582, check that month in range 1-12; for 1582,
    # check that month in range 10-12
    if ($valid) {
      if ($y == 1582) {
        unless (($m >= 10) and ($m <= 12)) {
          $valid = 0;
        }
        
      } else {
        unless (($m >= 1) and ($m <= 12)) {
          $valid = 0;
        }
      }
    }
    
  } elsif ($str =~ /^[0-9]{4}$/u) {
    # Year only -- get integer value and check in range [1582, 9999]
    my $y = int($str);
    unless (($y >= 1582) and ($y <= 9999)) {
      $valid = 0;
    }
    
  } else {
    # Unrecognized format
    $valid = 0;
  }
  
  # Return validity
  return $valid;
}

# Check whether a navigation target is in the proper format.
#
# Navigation targets must either be "#" or "#" followed by an ASCII
# letter followed by zero or more additional ASCII alphanumerics and
# underscores.
#
# This does NOT check whether the given target actually exists in the
# content XHTML file.
#
# Parameters:
#
#   1 : string - the target string to check
#
# Return:
#
#   1 if valid, 0 if not
#
sub check_target {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Valid flag starts set
  my $valid = 1;
  
  # Check format
  unless (($str =~ /^#$/u) or ($str =~ /^#[A-Za-z][A-Za-z0-9_]*$/u)) {
    $valid = 0;
  }
  
  # Return validity
  return $valid;
}

# Given an unescaped string, apply XML escaping appropriate for XML
# content that occurs as character data.
#
# This escapes & < > as &amp; &lt; &gt; respectively.
#
# Parameters:
#
#   1 : string - the unescaped string
#
# Return:
#
#   the escaped string
#
sub esc_xml_text {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Escape the ampersand first
  $str =~ s/&/&amp;/ug;
  
  # Escape the other unsafe characters
  $str =~ s/</&lt;/ug;
  $str =~ s/>/&gt;/ug;
  
  # Return escaped string
  return $str;
}

# Given an unescaped string, apply XML escaping appropriate for XML
# content that occurs within a double-quoted attribute value.
#
# This escapes & < > " as &amp; &lt; &gt; &quot; respectively.
#
# Parameters:
#
#   1 : string - the unescaped string
#
# Return:
#
#   the escaped string
#
sub esc_xml_att {
  # Should have exactly one argument
  ($#_ == 0) or die "Wrong number of arguments, stopped";
  
  # Get argument and set type
  my $str = shift;
  $str = "$str";
  
  # Escape the ampersand first
  $str =~ s/&/&amp;/ug;
  
  # Escape the other unsafe characters
  $str =~ s/</&lt;/ug;
  $str =~ s/>/&gt;/ug;
  $str =~ s/"/&quot;/ug;
  
  # Return escaped string
  return $str;
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
# The title of the book and unique identifier are also returned, so that
# these can be included in the NCX file.
#
# Parameters:
#
#   1 - reference to parsed <metadata> element content
#
#   2 : string - the code for the language to declare
#
#   3 : string - extra metadata to insert, or empty string if no extra
#   metadata
#
# Return:
#
#   1 : string - the <metadata> section that should be placed in the OPF
#   file, including the <metadata> tags
#
#   2 : string - the (unescaped) book title
#
#   3 : string - the (unescaped) unique ID of the book
#
sub gen_meta {
  # Should have exactly three arguments
  ($#_ == 2) or die "Wrong number of arguments, stopped";
  
  # Get arguments
  my $metadata   = shift;
  my $root_lang  = shift;
  my $extra_meta = shift;
  
  # Verify that metadata is an array ref
  (ref($metadata) eq 'ARRAY') or die "Wrong argument type, stopped";
  
  # Set language code type and check it
  $root_lang = "$root_lang";
  (check_language_code($root_lang)) or
    die "Invalid language code '$root_lang', stopped";
  
  # Set extra metadata to string
  $extra_meta = "$extra_meta";
  
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
        $new_e->{'role'} = lc($e->{'attrib'}->{'role'});
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
        $new_e->{'role'} = lc($e->{'attrib'}->{'role'});
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
  $meta_str = $meta_str . "    <dc:title>$pval</dc:title>\n";
  
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
  
  # Insert any extra metadata
  $meta_str = $meta_str . $extra_meta;
  
  # Finish the constructed metadata section
  $meta_str = $meta_str . "  </metadata>\n";
  
  # Return results
  return ($meta_str, $md{'title'}, $md{'identifier'}->{'value'});
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

# Recursively generate the navigation tree in the NCX file.
#
# This generates a sequence of <navPoint> elements, which may have
# nested elements within them.  It does NOT generate the surrounding
# <navMap> elements.
#
# The given reference must be to the content of the root <nav> element
# or to the content of a nested <node> element somewhere.
#
# Each <navPoint> element is given a playOrder one greater than the
# last.  The first playOrder that will be assigned to a generated
# element is passed as a parameter to this function.  You should pass a
# value of "1" the first time.
#
# Generated <navPoint> elements are given element IDs of the form
# "navp#" where # is an integer that equals the playOrder value.
#
# The element depth is used both to visually format indents in the
# generated NCX code and also to determine the maximum depth, which will
# be reported as a return value from this function.  You should pass a
# value of "1" when using this to parse the root <nav> element, and
# every nested element will have a depth one greater.
#
# All anchors are assumed to refer to a file named "content.html"
#
# Parameters:
#
#   1 - reference to parsed <nav> or <node> element content
#
#   2 : integer - the first playOrder number to assign
#
#   3 : integer - depth of this element
#
# Return:
#
#   1 : string - the generated NCX code
#
#   2 : integer - the total number of <navPoint> elements generated,
#   including recursively
#
#   3 : integer - the maximum depth that was reached recursively
#
sub gen_nav {
  # Should have exactly three arguments
  ($#_ == 2) or die "Wrong number of arguments, stopped";
  
  # Get arguments
  my $nave  = shift;
  my $pon   = shift;
  my $depth = shift;
  
  # Check/set types
  (ref($nave) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  $pon   = int($pon);
  $depth = int($depth);
  
  (($pon > 0) and ($depth > 0)) or
    die "Invalid parameter values, stopped";
  
  # Define result variables with appropriate initial values
  my $result  = '';
  my $reached = $depth;
  my $count   = 0;
  
  # Get the appropriate indent for generated elements on this level
  my $idt = '  ';
  for(my $i = 0; $i < $depth; $i++) {
    $idt = $idt . '  ';
  }
  
  # Go through all content
  for my $e (@$nave) {
  
    # Ignore if not a true element
    if ($e->{'type'} ne 'e') {
      next;
    }
    
    # Check that element is "node"
    ($e->{'name'} eq 'node') or
      die "Unrecognized element type in <nav> in XML metadata, stopped";
  
    # Must have name and target attributes
    (exists $e->{'attrib'}->{'name'}) or
      die "<node> missing name in XML metadata, stopped";
    (exists $e->{'attrib'}->{'target'}) or
      die "<node> missing target in XML metadata, stopped";
    
    # Get name and target attributes and validate target
    my $a_name   = "$e->{'attrib'}->{'name'}";
    my $a_target = "$e->{'attrib'}->{'target'}";
    
    (check_target($a_target)) or
      die "Invalid target '$a_target', stopped";
    
    # If target is just "#" replace it with "content.html" else suffix
    # it to "content.html"
    if ($a_target eq '#') {
      $a_target = "content.html";
    } else {
      $a_target = "content.html$a_target";
    }
    
    # Escape name as XML text and target as XML attribute
    $a_name   = esc_xml_text($a_name);
    $a_target = esc_xml_att($a_target);
    
    # If there is an optional xml:lang attribute, get that and escape as
    # attribute value
    my $has_lang = 0;
    my $new_lang;
    
    if (exists $e->{'attrib'}->{'xml:lang'}) {
      $has_lang = 1;
      $new_lang = "$e->{'attrib'}->{'xml:lang'}";
      (check_language_code($new_lang)) or
        die "Invalid language code '$new_lang', stopped";
      $new_lang = esc_xml_att($new_lang);
    }
  
    # Get the language suffix, which is empty if there is no explicit
    # attribute and otherwise adds an xml:lang attribute
    my $lang_suffix = '';
    if ($has_lang) {
      $lang_suffix = " xml:lang=\"$new_lang\"";
    }
  
    # Compute the current playOrder and then increase count
    my $cpo = $pon + $count;
    $count++;
  
    # Add the new navpoint, but do not close it yet
    $result = $result . <<EOD;
$idt<navPoint id="navp$cpo" playOrder="$cpo">
$idt  <navLabel$lang_suffix>
$idt    <text>$a_name</text>
$idt  </navLabel>
$idt  <content src="$a_target"/>
EOD

    # Recursive invocation for this element's content
    my $r_gen;
    my $r_count;
    my $r_reached;
    
    ($r_gen, $r_count, $r_reached) = gen_nav(
                                        $e->{'content'},
                                        $pon + $count,
                                        $depth + 1);
    
    # Update state from recursive results
    $result = $result . $r_gen;
    $count = $count + $r_count;
    if ($r_reached > $reached) {
      $reached = $r_reached;
    }

    # Now close this navpoint
    $result = $result . "$idt</navPoint>\n";
  }
  
  # If we didn't actually add any elements, we never reached this depth,
  # so decrease reached depth in that case
  if ($count < 1) {
    $reached--;
  }
  
  # Return results
  return ($result, $count, $reached);
}

# Generate the NCX file.
#
# The given reference must be to the content of the parsed <nav> 
# element, and this function assumes that fold_elements() has already
# been applied to it.
#
# This function assumes that all links refer to "content.html" or
# anchors within that file.
#
# The given language code should be the xml:lang attribute value from
# the <nav> element, or if there is no such attribute, the xml:lang
# attribute value from the root <spoor> element.
#
# Parameters:
#
#   1 - reference to parsed <nav> element content
#
#   2 : string - default language code
#
#   3 : string - the (unescaped) title of the E-Book
#
#   4 : string - the (unescaped) unique ID of the E-Book
#
# Return:
#
#   string - the full, generated NCX file
#
sub gen_ncx {
  # Should have exactly four arguments
  ($#_ == 3) or die "Wrong number of arguments, stopped";
  
  # Get the arguments
  my $ne         = shift;
  my $root_lang  = shift;
  my $book_title = shift;
  my $book_id    = shift;
  
  # Check/set types
  (ref($ne) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  $root_lang  = "$root_lang";
  $book_title = "$book_title";
  $book_id    = "$book_id";
  
  (check_language_code($root_lang)) or
    die "Invalid language code '$root_lang', stopped";
  
  # Recursively generate navigation content
  my $nav_content;
  my $nav_count;
  my $nav_depth;
  
  ($nav_content, $nav_count, $nav_depth) = gen_nav($ne, 1, 1);
  
  # Make sure we generated at least one navpoint
  ($nav_count > 0) or
    die "Must be at least one <node> in <nav> in XML metadata, stopped";
  
  # Escape the root language as an XML attribute, the book title as XML
  # text, and book ID as XML attribute
  $root_lang  = esc_xml_att($root_lang);
  $book_title = esc_xml_text($book_title);
  $book_id    = esc_xml_att($book_id);
  
  # Now generate the main text
  my $ncx_text = <<EOD;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN"
  "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx version="2005-1"
    xml:lang="$root_lang"
    xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <head>
    <meta name="dtb:uid" content="$book_id"/>
    <meta name="dtb:depth" content="$nav_depth"/>
    <meta name="dtb:generator" content="spoor"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle>
    <text>$book_title</text>
  </docTitle>
  <navMap>
$nav_content  </navMap>
</ncx>

EOD
  
  # Return the generated NCX file
  return $ncx_text;
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
# The given resource path array only refers to the extra resources that
# were passed on the command line.  This function always assumes that
# there will be a "content.html" XHTML file, that the generated NCX file
# will be placed in "toc.ncx", and that both these files and all
# reference files will be in the same directory in the archive.
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
  
  # Look for an image file in the file paths with a case-insensitive
  # name "cover" and store its name (without path) if found
  my $has_cover = 0;
  my $cover_name;
  for my $ar (@$ares) {
    # Get file name
    my $fname;
    (undef, undef, $fname) = File::Spec->splitpath($ar);
    
    # Check if we got a match
    if (($fname =~ /^cover.jpg$/ui) or
          ($fname =~ /^cover.jpeg$/ui) or
          ($fname =~ /^cover.png$/ui) or
          ($fname =~ /^cover.svg$/ui)) {
      $has_cover = 1;
      $cover_name = $fname;
      last;
    }
  }
  
  # If there is a cover, generate an extra <meta> tag for it, otherwise
  # set the extra meta data to empty string
  my $meta_extra = '';
  if ($has_cover) {
    $meta_extra =
      "    <meta name=\"cover\" content=\"$cover_name\"/>\n";
  }
  
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
  my $nav_root;
  
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
        $nav_root = $e;
        $has_nav = 1;
      } else {
        die "Multiple <nav> sections in XML, stopped";
      }
    }
  }
  
  # Make sure we found both sections
  ($has_metadata) or die "Missing <metadata> section in XML, stopped";
  ($has_nav) or die "Missing <nav> section in XML, stopped";
  
  # Build the metadata section, and also get the title and unique ID of
  # the E-Book
  my $meta_str;
  my $book_title;
  my $book_id;
  
  ($meta_str, $book_title, $book_id) = gen_meta(
                                        $metadata,
                                        $root_lang,
                                        $meta_extra);

  # Build the manifest section
  my $mani_str = gen_manifest($ares);
  
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
  
  # Determine the root language for the NCX file
  my $ncx_lang = $root_lang;
  if (exists $nav_root->{'attrib'}->{'xml:lang'}) {
    $ncx_lang = $nav_root->{'attrib'}->{'xml:lang'};
    (check_language_code($ncx_lang)) or
      die "Invalid language code '$ncx_lang', stopped";
  }
  
  # Generate the NCX file
  my $ncx_text = gen_ncx($nav, $ncx_lang, $book_title, $book_id);

  # Return the generated files
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

# Capture the current time for use in archive file metadata
#
my $ftime = time;

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
my $m;

# First off, we need to add a mimetype file declaring the file type
#
($m = $zip->addString('application/epub+zip', 'mimetype'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->desiredCompressionLevel(COMPRESSION_LEVEL_NONE);
$m->unixFileAttributes(0644);

# Next, we need the META-INF directory
#
($m = $zip->addDirectory('META-INF'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->unixFileAttributes(0755);

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

($m = $zip->addString($str_container, 'META-INF/container.xml'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
$m->unixFileAttributes(0644);

# Now create the OEBPS directory that will hold the book content
#
($m = $zip->addDirectory('OEBPS'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->unixFileAttributes(0755);

# Generate the OPF and NCX files from the XML metadata file
#
my $opf_text;
my $ncx_text;

($opf_text, $ncx_text) = parse_xml($arg_xml, \@arg_res);

# Manually encode the OPF and NCX files into UTF-8 since they might
# include Unicode but the Zip module seems to expect raw bytes
#
my $opf_bin = encode("UTF-8", $opf_text);
my $ncx_bin = encode("UTF-8", $ncx_text);

# Add the OPF and NCX files
#
($m = $zip->addString($opf_bin, 'OEBPS/content.opf'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
$m->unixFileAttributes(0644);
  
($m = $zip->addString($ncx_bin, 'OEBPS/toc.ncx'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
$m->unixFileAttributes(0644);

# Transfer the XHTML file into the OEBPS directory, renaming it
# content.html
#
($m = $zip->addFile($arg_html, 'OEBPS/content.html'))
  or die "Failed to add ZIP member, stopped";
$m->setLastModFileDateTimeFromUnix($ftime);
$m->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
$m->unixFileAttributes(0644);

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
  ($m = $zip->addFile($p, "OEBPS/$fname"))
    or die "Failed to add ZIP member, stopped";
  $m->setLastModFileDateTimeFromUnix($ftime);
  $m->unixFileAttributes(0644);
  if ($needs_compress) {
    $m->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
  } else {
    $m->desiredCompressionLevel(COMPRESSION_LEVEL_NONE);
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
