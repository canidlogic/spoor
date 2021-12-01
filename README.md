# Spoor

Create an EPUB-2 publication from an XHTML source file, an XML metadata file, and any associated image files.

## Syntax

    spoor.pl out.epub source.html metadata.xml main.css image1.png image2.jpg

The first argument is the path to the EPUB-2 publication to generate.  If something already exists at this path, it will be overwritten.

The second argument is the path to the XHTML file that defines the content of the E-Book.  Spoor does not validate or check the XHTML file in any way.  See "Open Publication Structure (OPS) 2.0.1" for specific recommendations about the XHTML used in EPUB files.  Note that the XHTML file may be given a different filename and extension within the EPUB file, so the XHTML file should not reference itself by name.

The third argument is the path to an XML file that defines metadata for the E-Book.  The specific XML format used for metadata is defined below.  Note that not everything that is in the XML file is guaranteed to be copied into the EPUB publication.  Only metadata that is supported by Spoor will be copied into the EPUB.

After the third argument is a sequence of zero or more resource files that are referenced from the XHTML document and should be packaged within the EPUB file.  The arguments on the command line are the full paths to each resource file.  When packaged in the EPUB file, however, the resource files will always be in the same directory as the XHTML file, so only the filename and extension are actually copied into the EPUB file.  As such, the XHTML file should reference these resource files assuming they are in the same directory, and it also means that the filename with extension of each resource must be unique.

The first resource file that has a name that is a case-insensitive match for `cover` and a file extension that indicates an image file will be set as the cover image for the EPUB file in the metadata declaration.  If there are no resource files matching this description, no cover image will be marked.

The file extension of each resource file _must_ be a case-insensitive match for one of the extensions in the following table:

     File extension |                    File type
    ================+==================================================
         .css       | Cascading Style Sheets 2 (CSS2)
    ----------------+--------------------------------------------------
         .png       | Portable Network Graphics (PNG) image
    ----------------+--------------------------------------------------
         .jpg       | Joint Photographic Experts Group (JPEG) image
         .jpeg      |
    ----------------+--------------------------------------------------
         .svg       | Scalable Vector Graphics 1.1 (SVG)

The filename before the extension must be a sequence of at least one and at most 250 US-ASCII alphanumeric or underscore characters.  In addition, the filename before the extension may not be a case-insensitive match for any of the following (which are special device names under Windows and DOS platforms):

- `AUX`
- `COM1` ... `COM9`
- `CON`
- `LPT1` ... `LPT9`
- `NUL`
- `PRN`

The filename with extension must be unique among all the resource files, even under case-insensitive comparisons.

## Metadata XML file format

The top level of the XML metadata file should look like this:

    <?xml encoding="UTF-8"?>
    <spoor format="html" xml:lang="en">
      ...
    </spoor>

The `format` attribute is required on the root tag.  Only the `html` format (case insensitive) is currently supported.

The `xml:lang` attribute is also required on the root tag, which declares the default language used for textual content within the metadata XML file.

Within the top-level element, there are two sections.  The sections may be in any order, but the sections may only appear once each.  Here is the internal section structure:

    <?xml encoding="UTF-8"?>
    <spoor format="html" xml:lang="en">
      <metadata>
        ...
      </metadata>
      <nav>
        ...
      </nav>
    </spoor>

Both sections are required.

### Metadata section

The metadata section within the XML metadata file declares metadata about the E-Book that will be embedded within the generated EPUB file.

The following table indicates the tags that are supported within the metadata section, whether they are required, whether it is possible to have multiple instances of a tag, and what attributes are supported:

     Metadata tag | Required? | Multiple? |      Attributes
    ==============+===========+===========+======================
        title     |    YES    |    no     | text
       creator    |    no     |    YES    | name, (role), (sort)
     description  |    no     |    no     | *
      publisher   |    no     |    no     | name
     contributor  |    no     |    YES    | name, (role), (sort)
         date     |    no     |    YES    | event, value
      identifier  |    YES    |    no     | scheme, value
        rights    |    no     |    no     | *

Attributes in parentheses are optional, while other attributes are required.  For elements that have an asterisk in the attribute column, this means that the metadata element has no attributes.  Instead, it encloses a plain-text description that is assigned to the attribute.  For example:

    <description>
      The description is enclosed with the
      surrounding &lt;description&gt; tags.
    </description>

Plain-text descriptions of this sort may use XML entities (as shown in the above example for encoding the left and right angle brackets), but they may not use any formatting elements.

Elements that have just a single attribute named `text` or `name` define the value of the corresponding metadata as the text string contained within that attribute value.  For example:

    <title text="Title of my example E-Book"/>

Elements that have a `name` attribute and optional `role` and `sort` attributes specify a required name value that is assigned to the corresponding metadata, optionally an alternate version of that name which is used for purposes of sorting, and optionally a role that determines the relationship of the named person to the work.  For example:

    <creator name="Joe Smith" sort="Smith, Joe" role="aut"/>

The `role` value must consist of exactly three US-ASCII letters (case insensitive).  Only the following roles are allowed:

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

For more information about the meaning of these roles, see section 2.2.6 of the Opening Packaging Format (OPF) 2.0 specification.

The `date` element associates a specific date with the document.  The `value` attribute must be in format `YYYY-MM-DD` or `YYYY-MM` or `YYYY` according to ISO 8601.  The `event` attribute must be either `creation` `publication` or `modification` (case insensitive).  Each `date` element must have an `event` that is unique within the E-Book, so there can be at most three instances of the `date` element.  For example:

    <date event="creation" value="2021-11-14"/>

Finally, the `identifier` element associates a unique ID with the E-Book.  This should be globally unique somehow, so that it can be used as a unique index for the book within an E-Reader's book catalog.  The `scheme` attribute must be a sequence of one or more US-ASCII alphanumeric characters that identifies (case insensitive) the kind of unique identifier, and the `value` is then the unique identifier of the E-Book within that scheme.  For example, if `ISBN` is used as the scheme, then the value will be the ISBN number that uniquely identifies this E-Book.  If you do not have an ISBN number, you can use the `URL` scheme, which allows you to provide a URL to uniquely identify the E-Book.  For example:

    <identifier scheme="URL" value="http://www.example.com/my-book-url"/>

(The URL is just used for unique identification purposes.  There does not need to be actual data at the URL in question.)

### Nav section

The navigation section of the XML metadata file defines a hierarchical tree structure for navigating through the E-Book, and determines how the nodes of the tree structure map to locations within the E-Book.  This section is required, and must have at least one node within it.

The navigation section tag may optionally have an `xml:lang` attribute that overrides the default language that was marked on the root `spoor` element.  Otherwise, the navigation section inherits the language declared for the `spoor` element.

Each node element within the navigation section may also optionally have an `xml:lang` attribute that explicitly declares the language for that node.  Nodes without an explicit language tag inherit the language of their parent node, or from the navigation section tag if they are a top-level node.

For example, consider the following:

    <nav xml:lang="en">
      <node name="Cover" ... />
      <node name="Introduction"  ... >
        <node name="Example subsection" ... />
        <node name="Je ne sais quoi" xml:lang="fr" ... >
          <node name="Plus de mots" ... />
          <node name="English once again" xml:lang="en" ... />
        </node>
      </node>
      <node name="Chapter 2: An old ending" ... />
      <node name="Chapter 3: A new beginning" ... />
    </nav>

In this navigation section, all nodes have a declared language of `en` (English), except for the _Je ne sais quoi_ node and the _Plus de mots_ node, which both have a declared language of `fr` (French).

These language declarations only apply to the name of the section within the navigation section.  They have no relationship to the language actually used for the text within the book (though of course that is usually the same).

Each node has a `target` that indicates the location within the E-Book that the node corresponds to.  Since the `html` format of Spoor only supports a single XHTML file, all targets must be anchor locations within this XHTML file.  If the anchor location `#` is used, it means the location is the start of the XHTML file.  Otherwise, the anchor location must begin with `#`, followed by an ASCII letter, followed by a sequence of zero or more US-ASCII alphanumerics and underscores that specify an element ID within the XHTML file that defines the location.  (Spoor does not actually check whether the anchor exists within the XHTML file.)

Finally, each node has a `name` that is the name of the section when it appears in the navigation structure in the E-Reader.  The language of this text is determined by the language associated with the node, as explained earlier in this section.  No automatic numbering is applied, so if there is some kind of numbering, it should be included in the name.

Example of a full navigation section:

    <nav xml:lang="en">
      <node name="Cover" target="#"/>
      <node name="Introduction" target="#intro">
        <node name="Example subsection" target="#subsection"/>
        <node name="Je ne sais quoi" target="#wh" xml:lang="fr">
          <node name="Plus de mots" target="#pdm"/>
          <node name="English once again" xml:lang="en" target="#en"/>
        </node>
      </node>
      <node name="Chapter 2: An old ending" target="#chapter2"/>
      <node name="Chapter 3: A new beginning" target="#chapter3"/>
    </nav>
