.ONESHELL:
.SHELL := /usr/bin/bash
.PHONY: org_policies org_setup project_setup platform_setup clean_project clean_all
CURRENT_FOLDER=$(shell basename "$$(pwd)")

all:
	$(MAKE) -C org_policies plan && $(MAKE) -C org_policies apply; \
	$(MAKE) -C org_setup plan && $(MAKE) -C org_setup apply; \
	$(MAKE) -C project_setup plan && $(MAKE) -C project_setup apply \
	$(MAKE) -C platform_setup plan && $(MAKE) -C platform_setup apply

org_policies:
	$(MAKE) -C org_policies plan && $(MAKE) -C org_policies apply

org_setup: org_policies
	$(MAKE) -C org_setup plan && $(MAKE) -C org_setup apply

project_setup: org_setup
	$(MAKE) -C project_setup plan && $(MAKE) -C project_setup apply

platform_setup: project_setup
	$(MAKE) -C platform_setup plan && $(MAKE) -C platform_setup apply

clean_all: clean_platform
	$(MAKE) -C org_setup plan-destroy && $(MAKE) -C org_setup destroy 

clean_project: clean_platform
	$(MAKE) -C project_setup plan-destroy && $(MAKE) -C project_setup destroy

clean_org: clean_project
	$(MAKE) -C org_setup plan-destroy && $(MAKE) -C org_setup destroy 

clean_platform:
	$(MAKE) -C platform_setup plan-destroy && $(MAKE) -C platform_setup destroy 
