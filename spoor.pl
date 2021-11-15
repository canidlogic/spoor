#!/usr/bin/env perl
use strict;

# Non-core dependencies
use XML::Tiny;

=head1 NAME

spoor.pl - Author an EPUB-2 E-Book.

=head1 SYNOPSIS

  spoor.pl out.epub path/to/source.spoor

=head1 DESCRIPTION

This script compiles an EPUB-2 E-Book from a source directory containing
an XHTML website and an XML description of how to package that website
into an EPUB E-Book.

EPUB E-Books are basically an XHTML-based website archived in a Zip file
with a special container and metadata format.  This script allows you to
provide a plain XHTML website and an XML description of the desired
book, and then generates the Zip file in the format expected by E-Book
readers supporting EPUB-2.

=head1 ABSTRACT

The script requires two parameters.  The first parameter is the path to
the EPUB-2 E-Book to create.  If the path already exists, it will be
overwritten.  The second parameter is the path to an XML file in a
special format that instructs the Spoor script how to assemble the
E-Book.

=head2 Source website

The source website that the E-Book is assembled from must be in the same
directory as the XML source file provided to the Spoor script.  The XML
source file must reference all files necessary to render the website
correctly.  All referenced files must be at the same directory level as
the XML source file; subdirectories are not allowed.  Additionally,
source file names have the following restrictions:

=over 4

=item 1.

Each source file name must consist of a name followed by an extension.

=item 2.

The name must be a sequence of one or more US-ASCII characters,
exclusively from the set of lowercase letters, decimal digits, and
underscore.  Uppercase letters are B<not> allowed!

=item 3.

The extension must be a US-ASCII period character followed by a sequence
of one or more US-ASCII lowercase letters, decimal digits, and
underscores.  Uppercase letters are B<not> allowed!

=item 4.

The file extension must be one of the allowed file extensions (see
below).

=item 5.

The total length of the source file name may not exceed 63 characters.

=back

Only a few specific file extensions are allowed for source files, and
each of these file extensions maps to one specific file type.  The
allowed file extensions and the types they map to are as follows:

   File extension |                    File type
  ================+==================================================
       .xhtml     |
       .xht       |
       .xml       | Extensible HyperText Markup Language 1.1 (XHTML)
       .html      |
       .htm       |
  ----------------+--------------------------------------------------
       .css       | Cascading Style Sheets 2 (CSS2)
  ----------------+--------------------------------------------------
       .png       | Portable Network Graphics (PNG) image
  ----------------+--------------------------------------------------
       .jpg       | Joint Photographic Experts Group (JPEG) image
       .jpeg      |
  ----------------+--------------------------------------------------
       .svg       | Scalable Vector Graphics 1.1 (SVG)

For maximum compatible with E-Readers, please observe the following
special notes regarding these formats:

=over 4

=item 1.

The HTML pages B<must> be XHTML 1.1.  Do B<not> use other HTML versions,
such as HTML 4.01 or HTML5.

=item 2.

Unlike a website, the HTML pages do not need to have an "index" document
that links them all together.  Instead, they will be linked in a single
book structure within the XML source file provided to Spoor.

=item 3.

See section 2 and 3 of the Open Publication Structure (OPS) 2.0
specification for specific recommendations on ensuring that XHTML files,
CSS style sheets, and SVG graphics files are compatible with E-Readers.

=item 4.

The website that will be embedded within the EPUB E-Book should be as
self-contained as possible, avoiding external references as much as
possible.

=back

=head2 XML source file

The XML source file passed to the Spoor script provides details for
which files comprise the website the E-Book will be based on and how
these pages will be assembled into an E-Book.

The top level of this XML source file should look like this:

  <?xml encoding="UTF-8"?>
  <spoor target="epub">
    ...
  </spoor>

The C<target> attribute is required on the root tag.  Only the C<epub>
type (case insensitive) is currently supported.

Within the top-level element, there are up to five different sections.
The sections may be in any order, but the sections may only appear once
each.  Here is the internal section structure:

  <?xml encoding="UTF-8"?>
  <spoor target="epub">
    <metadata>
      ...
    </metadata>
    <resources>
      ...
    </resources>
    <supplement>
      ...
    </supplement>
    <book>
      ...
    </book>
    <nav language="en">
      ...
    </nav>
  </spoor>

All sections are required, except for the resources and supplement
sections.  The following documentation sections describe each of these
data sections.

=head3 Metadata section

The metadata section within the XML source file declares metadata about
the E-Book that will be embedded within the generated EPUB file.

The language used for textual metadata in this section is the first
language declared by a language tag in this section (see below).

The following table indicates the tags that are supported within the
metadata section, whether they are required, whether it is possible to
have multiple instances of a tag, and what attributes are supported:

   Metadata tag | Required? | Multiple? |      Attributes
  ==============+===========+===========+======================
      title     |    YES    |    no     | text
     creator    |    no     |    YES    | name, (role), (sort)
   description  |    no     |    no     | *
    publisher   |    no     |    no     | name
   contributor  |    no     |    YES    | name, (role), (sort)
       date     |    no     |    YES    | event, value
    identifier  |    YES    |    no     | scheme, value
     language   |    no     |    YES    | code
      rights    |    no     |    no     | *

Attributes in parentheses are optional, while other attributes are
required.  For elements that have an asterisk in the attribute column,
this means that the metadata element has no attributes.  Instead, it
encloses a plain-text description that is assigned to the attribute.
For example:

  <description>
    The description is enclosed with the
    surrounding &lt;description&gt; tags.
  </description>

Plain-text descriptions of this sort may use XML entities (as shown in
the above example for encoding the left and right angle brackets), but
they may not use any formatting elements.

Elements that have just a single attribute named C<text> or C<name>
define the value of the corresponding metadata as the text string
contained within that attribute value.  For example:

  <title text="Title of my example E-Book"/>

Elements that have a C<name> attribute and optional C<role> and C<sort>
attributes specify a required name value that is assigned to the
corresponding metadata, optionally an alternate version of that name
which is used for purposes of sorting, and optionally a role that
determines the relationship of the named person to the work.  For
example:

  <creator name="Joe Smith" sort="Smith, Joe" role="aut"/>

The C<role> value must consist of exactly three US-ASCII letters (case
insensitive).  Only the following roles are allowed:

   Role code |           Role description
  ===========+=======================================
      adp    | Adapter
      ann    | Annotator
      arr    | Arranger
      art    | Artist
      asn    | Associated name
      aut    | Author
      aqt    | Author in quotations or text extracts
      aft    | Author of afterword, colophon, etc.
      aui    | Author of introduction, etc.
      ant    | Bibliographic antecedent
      bkp    | Book producer
      clb    | Collaborator
      cmm    | Commentator
      dsr    | Designer
      edt    | Editor
      ill    | Illustrator
      lyr    | Lyricist
      mdc    | Metadata contact
      mus    | Musician
      nrt    | Narrator
      oth    | Other
      pht    | Photographer
      prt    | Printer
      red    | Redactor
      rev    | Reviewer
      spn    | Sponsor
      ths    | Thesis advisor
      trc    | Transcriber
      trl    | Translator

For more information about the meaning of these roles, see section 2.2.6
of the Opening Packaging Format (OPF) 2.0 specification.

The C<language> element selects a specific language with the C<code>
attribute.  The Spoor script simply enforces the following requirements
on the language code:

=over 4

=item 1.

The language code may only contain US-ASCII alphanumeric characters and
hyphens.

=item 2.

The language code must have at least one character.

=item 3.

The language code must have at most 35 characters.

=item 4.

Neither the first nor last character may be a hyphen.

=item 5.

No hyphen may immediately follow another hyphen.

=back

For the semantics of language codes, see IETF RFC-5646 "Tags for
Identifying Languages", which is a component RFC of BCP 47.  Here is an
example of the tag, for declaring English as used in the United States:

  <language code="en-US"/>

If there is at least one language element declared, the first language
element will be used as the language for textual data within this
metadata section.

The C<date> element associates a specific date with the document.  The
C<value> attribute must be in format C<YYYY-MM-DD> or C<YYYY-MM> or
C<YYYY> according to ISO 8601.  The C<event> attribute must be either
C<creation> C<publication> or C<modification> (case insensitive).  Each
C<date> element must have an C<event> that is unique within the E-Book,
so there can be at most three instances of the C<date> element.  For
example:

  <date event="creation" value="2021-11-14"/>

Finally, the C<identifier> element associates a unique ID with the
E-Book.  This should be globally unique somehow, so that it can be used
as a unique index for the book within an E-Reader's book catalog.  The
C<scheme> attribute must be a sequence of one or more US-ASCII
alphanumeric characters that identifies (case insensitive) the kind of
unique identifier, and the C<value> is then the unique identifier of the
E-Book within that scheme.  For example, if C<ISBN> is used as the
scheme, then the value will be the ISBN number that uniquely identifies
this E-Book.  If you do not have an ISBN number, you can use the C<URL>
scheme, which allows you to provide a URL to uniquely identify the
E-Book.  For example:

  <identifier scheme="URL" value="http://www.example.com/my-book-url"/>

(The URL is just used for unique identification purposes.  There does
not need to be actual data at the URL in question.)

=head3 Resources section

The resources section of the XML source file lists all style sheets,
images, and graphics files that will be included in the E-Book.  The
section is optional, with the absence of the section meaning the same
thing as the section being present but empty.

The resources section stores a set of zero or more resource elements,
each of which has a required C<name> attribute that names the resource
file.  For example:

  <resources>
    <resource name="style.css"/>
    <resource name="pic01.jpg"/>
    <resource name="pic02.png"/>
  </resources>

All resource names must follow the restrictions given earlier in the
section "Source website."  Declaring a resource more than once is not
allowed.  Resource files must have the same parent directory as the XML
source file (that is, they must be in the same directory and not a
subdirectory).  The Spoor script will embed each named resource file
within the generated E-Book.

B<Important:> Resources files may not have any extension corresponding
to an XHTML text file.

=head3 Supplement section

The supplement section of the XML source file lists all XHTML text
documents that are B<not> part of the main reading order of the book.
The section is optional, with the absence of the section meaning the
same thing as the section being present but empty.

The supplement section stores a set of zero or more text elements, each
of which has a required C<name> attribute that names an XHTML file.  For
example:

  <supplement>
    <text name="pic01_desc.html"/>
    <text name="pic02_desc.html"/>
  </supplement>

All supplement names must follow the restrictions given earlier in the
section "Source website."  Declaring the same supplement more than once
is not allowed.  Supplement files must have the same parent directory as
the XML source file (that is, they must be in the same directory and not
a subdirectory).  The Spoor script will embed each supplement within the
generated E-Book.

All supplement names must furthermore have one of the file extensions
corresponding to an XHTML document.

Supplements should somehow be accessible from links in the main text
nodes with the book (see the "Book section" below).  They will not,
however, be directly included in the main reading sequence of the
E-Book.

=head3 Book section

The book section of the XML source file lists all XHTML text documents
that are part of the main reading order of the book.  The section is
required, and must have at least one text node within it.  For XHTML
files that are not part of the main reading order, put them instead in
the supplement section (see previous section).

The book section stores a sequence of one or more text elements, each of
which has a required C<name> attribute that names an XHTML file.  The
order is significant, and it determines the order in which the files
will be presented in the E-Reader.  For example:

  <book>
    <text name="main.html"/>
    <text name="chapter_2.html"/>
    <text name="chapter_3.html"/>
  </book>

All book text node names must follow the restrictions given earlier in
the section "Source website."  Declaring the same book text node more
than once is not allowed.  Book text nodes must have the same parent
directory as the XML source file (that is, they must be in the same
directory and not a subdirectory).  The Spoor script will embed each
book text node within the generated E-Book.

All book text node names must furthermore have one of the file
extensions corresponding to an XHTML document.  Finally, none of the
names of text nodes given in the book section may match any of the names
given in the supplement section; a text node can be in the supplement or
the book, but not both.

=head3 Navigation section

The navigation section of the XML source file defines a hierarchical
tree structure for navigating through the E-Book, and determines how the
nodes of the tree structure map to locations within the E-Book.  This
section is required, and must have at least one node within it.

The navigation section tag may optionally have a C<language> attribute
that determines the language used for textual data within the navigation
section.  If not specified, it is inherited from the first language
element defined within the metadata section, or else is left undefined
if there are no language elements in the metadata section.

Each node within the navigation section may optionally have a
C<language> attribute that sets the language for the node and all
descendant nodes.  If not specified, the node inherits the language
setting from the parent node, or from the navigation section tag if the
node has no node parent.

For example, consider the following:

  <nav language="en">
    <node name="Cover" ... />
    <node name="Introduction"  ... >
      <node name="Example subsection" ... />
      <node name="Je ne sais quoi" language="fr" ... >
        <node name="Plus de mots" ... />
        <node name="English once again" language="en" ... />
      </node>
    </node>
    <node name="Chapter 2: An old ending" ... />
    <node name="Chapter 3: A new beginning" ... />
  </nav>

In this navigation section, all nodes have a declared language of C<en>
(English), except for the I<Je ne sais quoi> node and the I<Plus de
mots> node, which both have a declared language of C<fr> (French).

These language declarations only apply to the name of the section within
the navigation section.  They have no relationship to the language
actually used for the text within the book (though of course that is
usually the same).

Each node has a C<target> that indicates the location within the E-Book
that the node corresponds to.  Each target must begin with the name of
one of the text nodes that was defined in either the supplement or the
book section.  Optionally, a pound sign followed by a string of one or
more US-ASCII alphanumerics may be suffixed to the text node name,
specifying an anchor name within the document.  Spoor does not check
whether these anchors actually exist within the document, though they
should.

Finally, each node has a C<name> that is the name of the section when it
appears in the navigation structure in the E-Reader.  The language of
this text is determined by the language associated with the node, as
explained earlier in this section.  No automatic numbering is applied,
so if there is some kind of numbering, it should be included in the
name.

Example of a full navigation section:

  <nav language="en">
    <node name="Cover" target="main.html#cover"/>
    <node name="Introduction" target="main.html#intro">
      <node name="Example subsection" target="main.html#subsection"/>
      <node name="Je ne sais quoi" target="main.html#wh" language="fr"/>
    </node>
    <node name="Chapter 2: An old ending" target="chapter_2.html"/>
    <node name="Chapter 3: A new beginning" target="chapter_3.html"/>
  </nav>

=cut

# @@TODO:

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
