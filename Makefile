.PHONY: all clean

OUTDIR = LithosphereRocketry.github.io
MDHDIR = md-html
MDDIR = md-pages
TITLESDIR = titles
PARTSDIR = parts
TEMPLATESDIR = templates
DEPDIR = embed-deps

DIRS = $(MDHDIR) $(TITLESDIR)

PROJNAMES = website nandy mollusc nanodeploy
ARTICLENAMES = cplusplus cromulent

REGTARGETS = $(patsubst $(TEMPLATESDIR)/%,$(OUTDIR)/%,$(wildcard $(TEMPLATESDIR)/*.html))
PROJTARGETS = $(foreach proj,$(PROJNAMES),$(OUTDIR)/$(proj).html)
ARTTARGETS = $(foreach art,$(ARTICLENAMES),$(OUTDIR)/$(art).html)
PYGMENT = $(OUTDIR)/pygmentize.css

PARTS = $(wildcard $(PARTSDIR)/*.html)

all: $(PYGMENT) $(REGTARGETS) $(PROJTARGETS) $(ARTTARGETS)

$(PYGMENT):
	pygmentize -S default -f html -a .codehilite > $@

$(MDHDIR)/%.html: $(MDDIR)/%.md md_cfg.json | $(MDHDIR)
	python -m markdown -x fenced_code -x codehilite -x toc -x footnotes -c md_cfg.json -f $@ < $<

$(TITLESDIR)/%.html: mktitle.py titles.cfg | $(TITLESDIR)
	./mktitle.py $*

$(DIRS): %:
	mkdir $@

$(PROJTARGETS) $(ARTTARGETS): $(OUTDIR)/%.html: $(MDHDIR)/%.html $(TITLESDIR)/%.html project-template.html $(PARTS) buildpage.py
	./buildpage.py -t project-template.html -o $@ -D PROJECT $< -D TITLE $(word 2, $^)

$(REGTARGETS): $(OUTDIR)/%: $(TEMPLATESDIR)/% $(TITLESDIR)/% $(PARTS) buildpage.py
	./buildpage.py -t $< -o $@ -D TITLE $(word 2, $^)

clean:
	rm -r $(DIRS) $(REGTARGETS) $(PROJTARGETS) $(PYGMENT)