
all: dvi

dvi: ijcnlp08.tex ijcnlp08.aux ijcnlp08.bbl
	latex ijcnlp08.tex

ijcnlp08.aux: ijcnlp08.tex
	latex ijcnlp08.tex

ijcnlp08.bbl: Bibliografie.bib
	bibtex ijcnlp08
	latex ijcnlp08.tex

pdflatex: ijcnlp08.tex
	pdflatex $^

pdf: ijcnlp08.dvi
	dvipdf ijcnlp08.dvi

clean:
	rm ijcnlp08.aux ijcnlp08.out ijcnlp08.log ijcnlp08.blg ijcnlp08.bbl

clean-all: clean
	rm ijcnlp08.pdf ijcnlp08.dvi
