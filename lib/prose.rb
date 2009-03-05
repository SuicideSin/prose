require 'cgi'
##
# Copyright (c) 2009 Alexis Sellier
#
#   Prose - A lightweight text to html parser inspired by Markdown & Textile
#
class Prose < String 
#
# Usage:
#
#   Prose.new(text).parse
#  or
#   Prose.parse text
#
# lite mode (no headers, escape html):
#
#   text = Prose.new(text).parse(true)
#
# Parser:
#
#   Document Title <h1>
#   ==============
#
#   Header <h2>
#   ------
#
#   # Sub-Header    <h3>
#   ## Sub-sub-Header <h4>
#   ..etc.. 
#   
#   <ul>    <ol>
#   - Milk    1. Milk
#   - Apples  2. Apples
#   - Coffee  3. Coffee
#   
#   << Blockquote >>           <blockquote>
#
#   "Click Here":http://www.github.com <a>
#   Click:http://www.google.com    <a>
#   
#   +-+-+-+  <hr>, must have empty line before and after
#   +=+=+
#   ---
#
#   *milk*   <strong>milk</strong>
#   _milk_   <em>milk</em>
#   @mlik@   <code>milk</code>
#   -milk-   <del>milk</del>
#   "milk"   <q>milk</q>
#   
#   hot--milk  &mdash
#   hot - milk   &ndash
#   (C),(R)    &copy, &reg
#   2 x 2 / 5  &times, &divide
#   ...      Ellipsis
#   
#   // Secret  Comment, won't show up in html
#   /* Secret */
#
# # #
  #    
  VERSION = '0.1'
  #
  # Glyph definitions
  #
  QuoteSingleOpen  =  '&lsquo;'
	QuoteSingleClose =  '&rsquo;'
	QuoteDoubleOpen  =  '&ldquo;'
	QuoteDoubleClose =  '&rdquo;'
	QuoteDoubleLow   =  '&bdquo;'
	Apostrophe       =  '&#8217;'
	Ellipsis         =  '&#8230;'
	Emdash           =  '&mdash;'
	Endash           =  '&ndash;'
	Multiply         =  '&times;'
	Divide           =  '&divide;'
	Trademark        =  '&#8482;'
	Registered       =  '&reg;'
	Copyright        =  '&copy;'
	Backslash        =  '&#92;'
	
	StartProse = "<!-- START PROSE -->\n"
	EndProse   = "\n<!-- END PROSE -->"
	
	#
	# *match* => <strong>replace</strong>
	#
	TAGS = {
    '*' => 'strong',
		'_' => 'em',
		'"' => 'q',
		'@' => 'code',
		'-' => 'del'
  }
  
  #
  # Match => Replace
  #
  GLYPHS = {
    # Comments 
		/[ \t]*[^:]\/\/.*(\n|\Z)/ => '\\1',
		/\/\*.*?\*\//m => '',
		
		# Horizontal Rulers 
		/\n\n[ \t]*[-=+]+(\n\n|\Z)/ => "\n\n<hr />\n\n",
		
		# em-dash and en-dash 
		/( ?)--( ?)/ => '\\1' + Emdash + '\\2',
		/\s-(?:\s|\Z)/  => ' ' + Endash + ' ',
		
		# ...    
		/\b( )?\.{3}/ => '\\1' + Ellipsis,
		
		# Arithmetics: 2 x 3, 6 / 2 
		/(\d+)( ?)x( ?)(?=\d+)/ => '\\1\\2' + Multiply + '\\3',
		/(\d+)( ?)\/( ?)(?=\d+)/ => '\\1\\2' + Divide + '\\3',
	
		# (tm) (r) and (c) 
		/\b ?[\(\[]tm[\]\)]/i => Trademark,
    /\b ?[\(\[]r[\]\)]/i  => Registered,
    /\b ?[\(\[]c[\]\)]/i  => Copyright,
		
		# Blockquotes 
		/<< ?(.+) ?>>\n/m => "<blockquote>\\1</blockquote>\n\n",
  }
  # Defines the order of the parsing.
  # When a tuple is used, Prose checks
  # if the second value matches @lite, 
  # before running it.
  PARSERS = [
    :whitespace, 
    [:html, true], 
    [:headers, false], 
    :links,
    :lists,
    :glyphs,
    :paragraphs,
    :tags,
    :backslashes
  ]
  
  def initialize( string ) 
    super( string ) 
  end
    
  def self.parse( text, lite = false )
    new( text ).to_html( lite )
  end

  def to_html( lite = false )
  #
  #   Run all the parsing in order
  #
  # #
    # The operations are done on +self+ as it is
    # the string to be parsed.
    # We go through each parser, checking if it matches
    # the current mode, and run it.
    @lite = lite
				
    StartProse + PARSERS.inject( self ) do |text, parser|
      ( parser.is_a?(Array) && parser.last == @lite ) || 
        parser.is_a?(Symbol) ?  
          send( parser.is_a?(Array) ? parser.first : parser, text ) : text
    end + EndProse
  end
  
  alias parse to_html
  
  def whitespace text
  #
  # Remove extraneous white-space
  #
	  text.strip.
	     gsub("\r\n", "\n").       # Convert DOS to UNIX
		   gsub(/\n{3,}/, "\n\n").     # 3+ to 2
		   gsub(/\n[ \t]+\n/, "\n\n") +  # Empty lines
		   "\n\n"            # Add whitespace at the end
  end
  
  def html text
    CGI.escapeHTML text
  end
  
  def backslashes text
  # Remove single backslashes, 
  # escape double ones
    text.gsub('\\\\', Backslash).delete '\\'
  end
  
  def tags text
  #
  # Parse *bold* _em_ -del- etc
  #
	  TAGS.inject( text ) do |text, (style, tag)|
			style = Regexp.escape( style )
			text.gsub(/([^\w\\])            # Non-word or backslash
			            #{style}            # Opening tag
			            ([^\n\t#{style}]+?) # Contents, which must not include the tag
			            #{style}            # Closing tag
			            ([^\w])             # Non-word character 
			          /x, 
			          "\\1<#{tag}>\\2</#{tag}>\\3")
		end
	end
	
	def glyphs text
	#
  # Replace some chars with better ones
  #
	  GLYPHS.inject( text ) do |text, (match, replace)|
      text.gsub( match, replace )
    end
	end
  
  def headers text
		text.
		gsub(/^(.+)[ \t]*\n=+[ \t]*\n+/, "<h1>\\1</h1>\n\n").   # ======
		gsub(/^(.+)[ \t]*\n-+[ \t]*\n+/, "<h2>\\1</h2>\n\n").   # ------
	  gsub(/^(\#{1,6})[ \t]*(.+?)[ \t]*\#*\n+/) do |match|    # #
		  lvl = ( $1.length + 2 ).to_s
  		"<h#{ lvl }>" + $2 + "</h#{ lvl }>\n\n"
		end
  end
  
  def lists text
  #
  # Match the whole list, then replace the individual rows
  #
    marker = /-|\d\./           # - or 1.
    text.gsub(/^                # Start on a new-line
                (#{marker})     # Any list marker
                (.+?)           # Everything, including new-lines, but not greedy
                \n(?!#{marker}) # A new-line which is not followed by a marker
              /xm) do |match|
                type = ($1 == '-') ? 'ul' : 'ol'
                "<#{type}>\n" + 
                  match.gsub(/^#{marker} ?(.+)$/, "\t<li>\\1</li>") + 
                "</#{type}>\n"
              end
  end
  
  def paragraphs text     
  #
	#	  Parse: \n\nfoo\n\n
	#	  Into: <p>foo</p>
  # 
  # # Split text into blocks.
    # If it's not already enclosed in tags, or an hr,
		# enclose it inside <p> tags
		text.split("\n\n").collect do |block|		  	
			if ! block.match(/^(<.+?>.+<.+?>)|(<hr \/>)$/m)
				"\n<p>" + block + "</p>\n"
			else
				block
			end
		end.join
  end
  
  # Line breaks
  def breaks text
    text.gsub(/([^\n])\n([^\n])/, "\\1<br />\n\\2")
  end
  
  def links text
  #
  #	Parse: "link":http://www.link.com
  #	Into: <a href="http://www.link.com">link</a>
  #  
    nofollow = "rel='nofollow'" if @lite
    
    text.gsub(/"([\w\s]+)":(http:\/\/[^\s]+)/,
          "<a #{nofollow} href='\\2'>\\1</a>").
         gsub(/(^":)http:\/\/[^\s]+/,
          "<a #{nofollow} href='\\1'>\\1</a>")
  end
end
