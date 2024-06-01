# The Website

Some time ago, I realized that I should probably be documenting my projects
somewhere. I've always greatly enjoyed long-form project blogs like those made
by [mitxela](https://mitxela.com/projects), so I figured I would write a few for
the various projects I've worked on and put them somewhere that people might
stumble across them.

The problem with this is that I am emphatically not a web designer. I find a lot
of both classic and modern web design frustrating; newer framework-based design
tends to add a lot of performance load to otherwise-simple sites and introduces
dependencies on public APIs that may disappear in the future; older pure-html
sites require you to copy-paste a lot of common elements across every page,
which is typically colloquially described as "really boring." So of course, for
this site I decided to make my own web-development framework from scratch, with
the goal of getting the best of both worlds; most likely it will end up being
the worst of both, but at the very least it will be fun.

## "Frameworks bad"

When I say I don't like framework-based design, I'm not actually opposed to the
idea of a web framework. Web frameworks are a great idea; there's a lot of
finicky boilerplate involved in making a good-looking webpage, and there's no
reason that every web developer should have to do it all from scratch. The real
issue I have is that most frameworks operate at runtime. For comparison, this is
a rough idea of what a simple 90s-style website might do every time someone
accesses it:

* Download the page's HTML document
* Parse and interpret the page's head
* Download and parse an external CSS stylesheet
* Parse and interpret the page's body
* Display the page

For comparison, a simple modern page with [Bootstrap](https://getbootstrap.com/)
has a bit heavier workload:

* Download the page's HTML document
* Parse and interpret the page's head
* Download and parse Bootstrap's CSS stylesheet from JSDelivr's CDN
* Download and parse another user-defined CSS stylesheet
* Parse and interpret the page's body, in a barebones state
* Download, compile, and run JQuery from its CDN
* Download, compile, and run Popper.js from JSDelivr's CDN
* Download, compile, and run Bootstrap's plugins from JSDelivr's CDN
* Update and re-render the page with everything that Bootstrap has added

Just to load this simple page, your browser has had to download a significant
amount of extra data from at least 2 external sources other than your website,
and compile (or worse, if you have an older browser, interpret) 3
industrial-grade pieces of software, just to show you some rectangles and text.
This is not a good situation; our computers and network connections are orders
of magnitude faster than they were in the 90s, and yet because of all of this
mess, pages load slower. In fact, the only reason that the site has to be
rendered in barebones form first is to give users something to look at for the
several seconds it takes to sort all of this out. Usually, our modern computers
and broadband internet are fast enough to brute-force their way through all of 
this and deliver a responsive-enough experience, but if you've ever tried to use
a big corporate page on an old mobile device or spotty cellular connection,
you'll know that that is very much "usually" and not "always."

## The other problem

Even with all the convenience of modern frameworks, there's still some features
that I've always found to be lacking. At least in Bootstrap, there doesn't seem
to be a good way to make basic templated widgets that you can standardize across
all of your pages -- for example, top bars or footers. What I've done in the
past is write a simple JQuery program that fetches and inserts small pieces of
HTML based on data attributes; however, this is not ideal, as mentioned above.
It causes your browser to have to go back and fetch a lot of tiny files, which
in addition to the bandwidth load of JQuery creates a lot of extra latency. In
general, it just doesn't make a lot of sense; there's no reason every single
person who views my page should have to assemble it from parts when the result
is never different.

## My goals

For this site, I had a couple of needs:

* **Minimal copy-pasting for me.** I want to minimize the amount of boilerplate
  I write per page; it's not fun, it creates more reasons for me to delay
  writing documentation, and if I decide to change common elements later down
  the line it creates a huge amount of mess.
* **Write in Markdown.** I'm a huge fan of Markdown; it's what all of my
  existing documentation uses, and it closely mirrors how I tend to format
  raw-text documents. Additionally, it's a great bit of dependency-reduction;
  because the syntax is based on common text-only punctuation styles, you don't
  really even need a Markdown renderer for it to be useful; .md files look fine
  in a plain-text editor.
* **Minimal runtime performance cost.** As mentioned above, slow-loading
  websites are bad. Not everybody has a fast computer or internet connection,
  and even if you do, there's no reason to waste it on trivial things.

## Making pages in Markdown

The first, and most painless, part of the process was using Markdown for pages.
This was done using the Python `markdown` library, and turned out to be
incredibly straightforward; originally I was planning on writing a custom script
with all of my own custom tweaks, but I didn't end up needing to change much
from the default settings, so I could just use the command-line interface. The
only wrinkle here was code formatting, but that was as simple as importing the
`fenced_code` and `codehilite` modules. The CodeHilite module relies on Pygment
for syntax highlighting, so I also generated a `pygmentize.css` file and added
it to my standard page setup.

For a sense of what this looks like, here's the Makefile code that generates the
project HTML snippets for this website, formatted via itself:

```Makefile
$(OUTDIR)/pygmentize.css:
	pygmentize -S default -f html -a .codehilite > $@

$(MDHDIR)/%.html: $(MDDIR)/%.md | $(MDHDIR)
	python -m markdown -x fenced_code -x codehilite -x toc -f $@ < $<
```

There's a few minor quirks with the Python Markdown implementation, as with most
implementations; Markdown is a very loosely specified language, so there are
often implementation differences from one site to another. However, only one
thing I actually use is different from the Github Flavored Markdown I'm used to
(bulleted lists require an extra leading newline) and the only actual issue I
encountered was that I needed to include the table-of-contents extension to
allow links to section headers; overall the experience is very smooth.

## Templating

The first fully-custom part of the site's infrastructure is basic "component"
templating. This is how things like the navigation bar at the top of the site
are implemented; it's a fairly dumb system, where all instances of a specific
tag (`<embed-file>`) are replaced by the contents of the file pointed to by its
`src` attribute. This was accomplished using the Python `lxml.html` library,
which makes this kind of transformation fairly painless. One funny quirk is that
because tags are inserted relative to the `<embed-file>` tag, they actually get
inserted *before* it before the placeholder tag is destroyed; the last tag inserted will always be the closest to the placeholder, so inserting them after
results in them being placed in reverse order.

A more advanced feature of the templating is the ability to define aliases at the command line. In order to avoid the pain of string-searching and accidental
substitution, these have to be full filenames; only embeds whose sources exactly
match a defined alias will be substituted. The main use case for this feature is
generating these project pages. While all the unique pages such as the homepage
can have their own templates, the project pages need to share a format; 
therefore, they all are generated from the same HTML template and get the actual
article content based on an alias. This means that a simple Makefile rule like
this can cover all of them:

```Makefile
$(PROJTARGETS): $(OUTDIR)/%.html: $(MDHDIR)/%.html project-template.html $(PARTS) buildpage.py
	./buildpage.py -t project-template.html -o $@ -D PROJECT $<
```

The templating program (buildpage.py in the source repository) actually also
supports a few bonus features that aren't used here; it can search a list of
directories besides just the working directory, and it can spit out a list of
dependencies for the purposes of automating dependency-checking. Neither of
these features actually ended up being that useful here; I know where my files
should be located for the most part, and passing a dependency list to `make` is
a fairly arcane process that I didn't really feel like digging into.

## Generated sites and Github

Probably the biggest issue with this setup is in how it interacts with Github
Pages. Github Pages expects website files to be committed to the website repository; since the actual files here are generated, this makes the site-updating process a little ugly. Whatever gets generated by the process
above then has to get committed to a repository, so the actual Pages repository
exists as a submodule within this one; there's some weird interactions there
since submodules like to be in detached-HEAD and Pages likes to be on a real
branch. There may be a better way to integrate all of this with Github Actions,
but for now, this is how I'm keeping it.

## Future work

A major issue with the site as currently conceived is that every project needs
to have a tile in the project table-of-contents page, which are built mostly
by hand. This is because the templating as-built doesn't have the capability to
insert components programmatically; in the future, it would be nice to have
these tiles auto-generated, but it adds a fair amount of complexity to the
templating program, so I'm just going to leave it as-is for now.

## Using the tools for your own site

Like most of my projects, all code associated with this site is distributed
under the GPL, so you can use it under those terms. The templating portion
happens in the file `buildpage.py`; it presents a basic CLI and is reasonably
well-documented. If you have a use-case that requires just the templating for
a one-off application, it's perfectly reasonable to use it as a standalone tool.

The messier part of the project is the `Makefile`. This is what determines what
pages need to be built; it's fairly tailored to my specific layout and requires
a reasonable number of GNU-specific extensions. If you're looking to use this
whole system in your own project, you could probably adapt it, but it may not be
completely plug-and-play.