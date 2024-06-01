.PHONY: all clean

OUTDIR = LithosphereRocketry.github.io
MDHDIR = md-html
MDDIR = md-pages
TILESDIR = tiles
PARTSDIR = parts
TEMPLATESDIR = templates
DEPDIR = embed-deps

DIRS = $(MDHDIR)

PROJNAMES = website

REGTARGETS = $(patsubst $(TEMPLATESDIR)/%,$(OUTDIR)/%,$(wildcard $(TEMPLATESDIR)/*.html))
PROJTARGETS = $(foreach proj,$(PROJNAMES),$(OUTDIR)/$(proj).html)
PYGMENT = $(OUTDIR)/pygmentize.css

PARTS = $(wildcard $(PARTSDIR)/*.html)

all: $(PYGMENT) $(REGTARGETS) $(PROJTARGETS)

$(PYGMENT):
	pygmentize -S default -f html -a .codehilite > $@

$(MDHDIR)/%.html: $(MDDIR)/%.md | $(MDHDIR)
	python -m markdown -x fenced_code -x codehilite -x toc -f $@ < $<

$(DIRS): %:
	mkdir $@

$(PROJTARGETS): $(OUTDIR)/%.html: $(MDHDIR)/%.html project-template.html $(PARTS) buildpage.py
	./buildpage.py -t project-template.html -o $@ -D PROJECT $<

$(REGTARGETS): $(OUTDIR)/%: $(TEMPLATESDIR)/% $(PARTS) buildpage.py
	./buildpage.py -t $< -o $@

clean:
	rm -r $(MDHDIR) $(REGTARGETS) $(PROJTARGETS) $(PYGMENT)