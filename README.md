# secondary-analysis

[![Travis (.org) branch](https://img.shields.io/travis/HumanCellAtlas/secondary-analysis/master.svg?label=Unit%20Test%20on%20Travis%20CI%20&style=flat-square&logo=Travis)](https://travis-ci.org/HumanCellAtlas/secondary-analysis)
[![Snyk Vulnerabilities for GitHub Repo (Specific Manifest)](https://img.shields.io/snyk/vulnerabilities/github/HumanCellAtlas/secondary-analysis/dashboards/requirements.txt.svg?label=Snyk%20Dashboards%20Vulnerabilities&logo=Snyk)](https://snyk.io/test/github/HumanCellAtlas/secondary-analysis?targetFile=dashboards/requirements.txt)
[![Snyk Vulnerabilities for GitHub Repo (Specific Manifest)](https://img.shields.io/snyk/vulnerabilities/github/HumanCellAtlas/secondary-analysis/tests/integration_test/requirements.txt.svg?label=Snyk%20Integration%20Test%20Vulnerabilities&logo=Snyk)](https://snyk.io/test/github/HumanCellAtlas/secondary-analysis?targetFile=tests/integration_test/requirements.txt)
[![Snyk Vulnerabilities for GitHub Repo (Specific Manifest)](https://img.shields.io/snyk/vulnerabilities/github/HumanCellAtlas/secondary-analysis/tests/load_test/requirements.txt.svg?label=Snyk%20Load%20Test%20Vulnerabilities&logo=Snyk)](https://snyk.io/test/github/HumanCellAtlas/secondary-analysis?targetFile=tests/load_test/requirements.txt)
[![Snyk Vulnerabilities for GitHub Repo (Specific Manifest)](https://img.shields.io/snyk/vulnerabilities/github/HumanCellAtlas/secondary-analysis/tests/scale_test/requirements.txt.svg?label=Snyk%20Scale%20Test%20Vulnerabilities&logo=Snyk)](https://snyk.io/test/github/HumanCellAtlas/secondary-analysis?targetFile=tests/scale_test/requirements.txt)
[![Snyk Vulnerabilities for GitHub Repo (Specific Manifest)](https://img.shields.io/snyk/vulnerabilities/github/HumanCellAtlas/secondary-analysis/dev-requirements.txt.svg?label=Snyk%20Dev%20Dependencies%20Vulnerabilities&logo=Snyk)](https://snyk.io/test/github/HumanCellAtlas/secondary-analysis?targetFile=dev-requirements.txt)

![Github](https://img.shields.io/badge/python-3.6-green.svg?style=flat-square&logo=python&colorB=blue)
![GitHub](https://img.shields.io/github/license/HumanCellAtlas/secondary-analysis.svg?style=flat-square&colorB=blue)
[![Code style: black](https://img.shields.io/badge/Code%20Style-black-000000.svg?style=flat-square)](https://github.com/ambv/black)

This repo is the gateway of the Secondary Analysis Service which is part of the Human Cell Atlas Data Coordination Platform, containing the testing suites, automations and utility scirpts of the Secondary Analysis Service. This repo also serves as a issue tracker and hosting all of the tickets of the Secondary Analysis Service.

**[Architectural Diagram](https://www.lucidchart.com/invitations/accept/b992daa6-9c66-41ef-9a12-7d47541d8024)**
![DSS Sync SFN diagram](https://www.lucidchart.com/publicSegments/view/81f35afc-2fcb-4f75-8d78-abfc8d2681fa/image.png)

Other Secondary Analysis Service repos:

- [Cromwell Tools](https://github.com/broadinstitute/cromwell-tools): A collection of Python clients and accessory scripts for interacting with the [Cromwell workflow execution engine](https://github.com/broadinstitute/cromwell) - a scientific workflow engine designed for simplicity and scalability

- [Falcon](https://github.com/HumanCellAtlas/falcon): Queueing system that (after launching) throttles and inititates workflows 

- [Lira](https://github.com/HumanCellAtlas/lira): Listens to storage service notifications and launches workflows

- [Pipeline Tools](https://github.com/HumanCellAtlas/pipeline-tools): Contains Data Coordination Platform adapter pipelines and associated tools

- [scTools](https://github.com/HumanCellAtlas/sctools): Tools for single cell data processing

- [Secondary Analysis Deploy](https://github.com/HumanCellAtlas/secondary-analysis-deploy): Contains the deployment configuration and scripts for the Pipeline Execution Service

- [Skylab Analysis](https://github.com/HumanCellAtlas/skylab-analysis): Analysis and benchmarking reports for standardized HCA pipelines

- [Skylab](https://github.com/HumanCellAtlas/skylab): Standardized HCA data processing pipelines

## Development

### File Structure Layout

```
./
├── certs                  # The scripts to renew TLS certs
├── dashboards             # The scripts to create log-based metrics on Google Cloud
├── deploy
│   └── job-manager        # The scripts to deploy Job Manager for Cromwell
├── monitor                # The scripts to setup quotas monitors
├── operations             # The "BIG RED BUTTON" scripts of Secondary Analysis
└── tests
    ├── integration_test   # The integration test suite
    ├── load_test          # The load test suite
    └── scale_test         # The scaling test suite and associated scripts
```

### Code Style

The Secondary Analysis code base is complying with the PEP-8 and using [Black](https://github.com/ambv/black) to 
format our code, in order to avoid "nitpicky" comments during the code review process so we spend more time discussing about the logic, not code styles.

In order to enable the auto-formatting in the development process, you have to spend a few seconds setting up the `pre-commit` the first time you clone the repo. It's highly recommended that you install the packages within a [`virtualenv`](https://virtualenv.pypa.io/en/latest/userguide/).

1. Install `pre-commit` by running: `pip install pre-commit` (or simply run `pip install -r requirements.txt`).
2. Run `pre-commit install` to install the git hook.

Once you successfully install the `pre-commit` hook to this repo, the Black linter/formatter will be automatically triggered and run on this repo. Please make sure you followed the above steps, otherwise your commits might fail at the linting test!

_If you really want to manually trigger the linters and formatters on your code, make sure `Black` and `flake8` are installed in your Python environment and run `flake8 DIR1 DIR2` and `black DIR1 DIR2 --skip-string-normalization` respectively._