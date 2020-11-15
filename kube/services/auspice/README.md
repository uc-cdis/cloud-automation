Build Status GitHub CI Status NPM version License AGPL v3

About Nextstrain

Nextstrain is an open-source project to harness the scientific and public health potential of pathogen genome data. We provide a continually-updated view of publicly available data with powerful analytics and visualizations showing pathogen evolution and epidemic spread. Our goal is to aid epidemiological understanding and improve outbreak response.

Resulting data and inferences are available live at the website nextstrain.org.

About Auspice

Definition: Observation by an augur, ie a prophetic sign.

Auspice is an open-source interactive web app for visualizing phylogenomic data. It may be used in tandem with nextstrain's bioinformatics toolkit augur or on its own. Auspice may be used to explore datasets locally or run as a server to share results.

Documentation

Full documentation may be found at: nextstrain.github.io/auspice. The following are helpful when beginning to use Auspice:

Overview of how Auspice fits together with other Nextstrain tools
Auspice documentation
Quickstart

Installation

Install auspice for use as a global command. This requires nodejs 10+. We recommend using a conda environment, but this is not the only way. (See here for more installation methods & help).

Install with conda (Recommended)

Create and activate a conda environment:

conda create --name auspice nodejs=10
conda activate auspice
Now that the conda environment is activated, install auspice:

npm install --global auspice
Install from source

git clone https://github.com/nextstrain/auspice.git
cd auspice
npm install --global .
Obtain datasets to display

To get up & running, you'll need datasets to visualise. (Please see the nextstrain docs for tutorials on how to run your own analyses.)

If you've installed auspice from npm you may get datasets to display via:

mkdir data
curl http://data.nextstrain.org/zika.json --compressed -o data/zika.json
curl http://data.nextstrain.org/ncov.json --compressed -o data/ncov.json
...
If you've installed auspice from source, we have helper scripts to make all the datasets & narratives you see on nextstrain.org available locally:

# from the auspice src directory
npm run get-data
npm run get-narratives
Run auspice

auspice view --datasetDir data
And view auspice in the browser at localhost:4000

If you are editing source code, running the following command will allow hot-reloading.

auspice develop --datasetDir data
CLI (Command Line Interface)

Run auspice --help or auspice view --help to see all the available command line options.

Contributor Information

We have received a number of generous offers to contribute developer effort to nextstrain (and auspice) following our work on hCoV-19. We welcome contributions! To get started, please review these resources before submitting a pull request:
Contributor guide
Project board with available issues
Developer docs for Auspice
This project strictly adheres to the Contributor Covenant Code of Conduct.

License and copyright

Copyright 2014-2020 Trevor Bedford and Richard Neher.

Source code to Nextstrain is made available under the terms of the GNU Affero General Public License (AGPL). Nextstrain is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.