.ONESHELL:
.SHELL := /usr/bin/bash
.PHONY: org_setup project_setup clean_project clean_all
CURRENT_FOLDER=$(shell basename "$$(pwd)")

all:
	$(MAKE) -C org_setup plan && $(MAKE) -C org_setup apply; \
	$(MAKE) -C project_setup plan && $(MAKE) -C project_setup apply

org_setup:
	$(MAKE) -C org_setup plan && $(MAKE) -C org_setup apply

project_setup: org_setup
	$(MAKE) -C project_setup plan && $(MAKE) -C project_setup apply

clean_all: clean_project
	$(MAKE) -C org_setup plan-destroy && $(MAKE) -C org_setup destroy 

clean_project:
	$(MAKE) -C project_setup plan-destroy && $(MAKE) -C project_setup destroy

clean_org: clean_project
	$(MAKE) -C org_setup plan-destroy && $(MAKE) -C org_setup destroy 
