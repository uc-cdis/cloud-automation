# Configuring UI for a Data Commons
## Introduction
The standard file structure (located in `gitops-qa` for QA environments or `cdis-manifest` for staging/production environments) for a given data commons is as follows:
```
/project.io
  /portal
    - gitops-favicon.ico
    - gitops-logo.png
    - gitops.css 
    - gitops.json
  - etlMapping.yaml
  - manifest.json
```
The `portal` folder contains Windmill specific UI elements, the `etlMapping` file details what nodes and attributes to grab from Postgres and put into ElasticSearch for the Data and File Explorers, and the `manifest` file contains service versions and deployment information. We will go over each in detail in the following sections.
## Portal Folder
This folder contains all of the Windmill specific configuration. `gitops-favicon.ico` and `gitops-logo.png` should contain the images used for a commons’ favicon (the tiny image that appears in the browser tab) and the logo for the commons.

`gitops.css` contains the CSS overrides for a commons. This is usually empty or has few lines, except for commons that want a different color scheme than the default Gen3 color scheme. AnVIL is an example.

`gitops.json` is a larger, more important file that details what UI features should be deployed for a commons, and what the configuration for these features should be. This is commonly referred to as the “portal config” file. Below is an example, with inline comments describing what each JSON block configures, as well as which properties are optional and which are required (if you are looking to copy/paste configuration as a start, please use something in the Github repo as the inline comments below will become an issue):
```
{
  "gaTrackingId": "xx-xxxxxxxxx-xxx", // required; the Google Analytics ID to track statistics
  "graphql": { // required; start of query section - these attributes must be in the dictionary
    "boardCounts": [ // required; graphQL fields to query for the homepage chart
      {
        "graphql": "_case_count", // required; graphQL field name for aggregate count
        "name": "Case", // required; human readable name of field
        "plural": "Cases" // required; human readable plural name of field
      },
      {
        "graphql": "_study_count",
        "name": "Study",
        "plural": "Studies"
      },
      {
        "graphql": "_aliquot_count",
        "name": "Aliquot",
        "plural": "Aliquots"
      }
    ],
    "chartCounts": [ // required;
      {
        "graphql": "_case_count",
        "name": "Case"
      },
      {
        "graphql": "_study_count",
        "name": "Study"
      }
    ],
    "projectDetails": "boardCounts" // required; which JSON block above to use for displaying aggregate properties on the submission page (www.project.io/submission)
  },
  "components": {
    "appName": "Gen3 Generic Data Commons", // required; title of commons that appears on the homepage
    "index": { // required; relates to the homepage
      "introduction": { // optional; text on homepage
        "heading": "", // optional; title of introduction
        "text": "This is an example Gen3 Data Commons", // optional; text of homepage
        "link": "/submission" // optional; link for button underneath the text
      },
      "buttons": [ // optional; button “cards” displayed on the bottom of the homepage
        {
          "name": "Define Data Field", // required; title of card
          "icon": "planning", // required; name of icon to display on card located in /img/icons
          "body": "Please study the dictionary before you start browsing.", // required; card text
          "link": "/DD", // required; link for button
          "label": "Learn more" // required; title of button that leads to link above
        },
        {
          "name": "Explore Data",
          "icon": "explore",
          "body": "Explore data interactively.",
          "link": "/explorer",
          "label": "Explore data"
        },
        {
          "name": "Analyze Data",
          "icon": "analyze",
          "body": "Analyze your selected cases using Jupyter Notebooks in our secure cloud environment.",
          "link": "/workspace",
          "label": "Run analysis"
        }
      ],
      "homepageChartNodes": [ // optional; used for tiered access on the homepage. This means that the charts on the homepage will be available to the public.
        {
          "node": "case", // required; GraphQL field name of node to show a chart for
          "name": "Cases" // required; plural human readable name of node
        },
        {
          "node": "study",
          "name": "Studies"
        },
        {
          "node": "aliquot",
          "name": "Aliquots"
        }
      ]
    },
    "navigation": { // required; details what should be in the navigation bar
      "items": [ // required; the buttons in the navigation bar
        {
          "icon": "dictionary", // required; icon from /img/icons for the button
          "link": "/DD", // required; the link for the button
          "color": "#a2a2a2", // optional; hex color of the icon
          "name": "Dictionary" // required; text for the button
        },
        {
          "icon": "exploration",
          "link": "/explorer",
          "color": "#a2a2a2",
          "name": "Exploration"
        },
        {
          "icon": "workspace",
          "link": "/workspace",
          "color": "#a2a2a2",
          "name": "Workspace"
        },
        {
          "icon": "profile",
          "link": "/identity",
          "color": "#a2a2a2",
          "name": "Profile"
        }
      ]
    },
    "topBar": { // required if useArboristUI is true, else optional
      "items": [
        {
          "icon": "upload",
          "link": "/submission",
          "name": "Submit Data"
        },
        {
          "link": "https://gen3.org/resources/user/",
          "name": "Documentation"
        }
      ]
    },
    "login": { // required; what is displayed on the login page (/login)
      "title": "Gen3 Generic Data Commons", // optional; title for the login page
      "subTitle": "Explore, Analyze, and Share Data", // optional; subtitle for login page
      "text": "This is a generic Gen3 data commons.", // optional; text on the login page
      "contact": "If you have any questions about access or the registration process, please contact ", // optional; text for the contact section of the login page
      "email": "support@datacommons.io", // optional; email for contact
      "image": "gene" // optional; images displayed on the login page
    },
    "footerLogos": [ // optional; logos to be displayed in the footer, usually sponsors
      {
        "src": "/src/img/gen3.png", // required; src path for the image
        "href": "https://ctds.uchicago.edu/gen3", // required; link for image
        "alt": "Gen3 Data Commons" // required; alternate text if image won’t load
      },
      {
        "src": "/src/img/createdby.png",
        "href": "https://ctds.uchicago.edu/",
        "alt": "Center for Translational Data Science at the University of Chicago"
      }
    ],
    "categorical9Colors": ["#c02f42", "#175676", "#59CD90", "#F2DC5D", "#40476D", "#FFA630", "#AE8799", "#1A535C", "#462255"], // optional; colors for the graphs both on the homepage and on the explorer page (will be used in order)
    "categorical2Colors": ["#6d6e70", "#c02f42"] // optional; colors for the graphs when there are only 2 colors (bar and pie graphs usually)
  },
  "requiredCerts": [], // optional; do users need to take a quiz or agree to something before they can access the site?
  "featureFlags": { // optional; will hide certain parts of the site if needed
    "explorer": true // required; indicates the flag and whether to hide it or not
  },
  "dataExplorerConfig": { // required; configuration for the Data Explorer (/explorer)
    "charts": { // optional; indicates which charts to display in the Data Explorer
      "project_id": { // required; GraphQL field to query for a chart (ex: this one will display the number of projects, based on the project_id)
        "chartType": "count", // required; indicates this chart will display a “count”
        "title": "Projects" // required; title to display on the chart
      },
      "case_id": {
        "chartType": "count",
        "title": "Cases"
      },
      "gender": {
        "chartType": "pie", // required; pie chart type
        "title": "Gender"
      },
      "race": {
        "chartType": "bar", // required; bar chart type
        "title": "Race"
      },
    },
    "filters": { // required; details facet configuration for the Data Explorer
      "tabs": [ // required; divides facets into tabs
        {
          "title": "Diagnosis", // required; title of the tab
          "fields": [ // GraphQL fields (node attributes) to list out facets
            "diastolic_blood_pressure",
            "systolic_blood_pressure",
          ]
        },
        {
          "title": "Case",
          "fields": [
            "project_id",
            "race",
            "ethnicity",
            "gender",
            "bmi",
            "age_at_index"
          ]
        }
      ]
    },
    "table": { // required; configuration for Data Explorer table
      "enabled": true, // required; indicates if the table should be enabled or not by default
      "fields": [ // required; fields (node attributes) to include to be displayed in the table
        "project_id",
        "race",
        "ethnicity",
        "gender",
        "bmi",
        "age_at_index",
        "diastolic_blood_pressure",
        "systolic_blood_pressure",
      ]
    },
    "dropdowns": { // optional; lists dropdowns if you want to combine multiple buttons into one dropdown (ie. Download dropdown has Download Manifest and Download Clinical Data as options)
      "download": { // required; id of dropdown button
        "title": "Download" // required; title of dropdown button
      }
    },
    "buttons": [ // required; buttons for Data Explorer
      {
        "enabled": true, // required; if the button is enabled or disabled
        "type": "data", // required; button type - what should it do? Data = downloading clinical data
        "title": "Download All Clinical", // required; title of button
        "leftIcon": "user", // optional; icon on left from /img/icons
        "rightIcon": "download", // optional; icon on right from /img/icons
        "fileName": "clinical.json", // required; file name when it is downloaded
        "dropdownId": "download" // optional; if putting into a dropdown, the dropdown id
      },
      {
        "enabled": true,
        "type": "manifest", // required; manifest = create file manifest type
        "title": "Download Manifest",
        "leftIcon": "datafile",
        "rightIcon": "download",
        "fileName": "manifest.json",
        "dropdownId": "download"
      },
      {
        "enabled": true,
        "type": "export", // required; export = export to Terra type
        "title": "Export All to Terra",
        "rightIcon": "external-link"
      },
      {
        "enabled": true,
        "type": "export-to-pfb", // required; export-to-pfb = export to PFB type
        "title": "Export to PFB",
        "leftIcon": "datafile",
        "rightIcon": "download"
      },
      {
        "enabled": true,
        "type": "export-to-workspace", // required; export-to-workspace = export to workspace type
        "title": "Export to Workspace",
        "leftIcon": "datafile",
        "rightIcon": "download"
      }
    ],
    "guppyConfig": { // required; how to configure Guppy to work with the Data Explorer
      "dataType": "case", // required; must match the index “type” in the guppy configuration block in the manifest.json
      "nodeCountTitle": "Cases", // required; plural of root node
      "fieldMapping": [ // optional; a way to rename GraphQL fields to be more human readable
        { "field": "consent_codes", "name": "Data Use Restriction" },
        { "field": "bmi", "name": "BMI" }
      ],
      "manifestMapping": { // optional; how to configure the mapping between cases/subjects/participants and files. This is used to export or download files that are associated with a cohort. It is basically joining two indices on specific GraphQL fields
        "resourceIndexType": "file", // required; what is the type of the index (must match the guppy config block in manifest.json) that contains the resources you want a manifest of?
        "resourceIdField": "object_id", // required; what is the identifier in the manifest index that you want to grab?
        "referenceIdFieldInResourceIndex": "case_id", // required; what is the field in the manifest index you want to make sure matches a field in the cohort?
        "referenceIdFieldInDataIndex": "case_id" // required; what is the field in the case/subject/participant index you are using to match with a field in the manifest index?
      },
      "accessibleFieldCheckList": ["project_id"], // optional; only useful when tiered access is enabled (tier_access_level=regular). When tiered access is on, portal needs to perform some filtering to display data explorer UI components according to user’s accessibility. Guppy will make queries for each of the fields listed in this array and figure out for each fields, what values are accessible to the current user and what values are not.
      "accessibleValidationField": "project_id" // optional; only useful when tiered access is enabled (tier_access_level=regular). This value should be selected from the “accessibleFieldCheckList” variable. Portal will use this field to check against the result returned from Guppy with “accessibleFieldCheckList” to determine if user has selected any unaccessible values on the UI, and changes UI appearance accordingly.
    },
    "getAccessButtonLink": "https://dbgap.ncbi.nlm.nih.gov/", // optional; for tiered access, if a user wants to get access to the data sets what site should they visit?
    "terraExportURL": "https://bvdp-saturn-dev.appspot.com/#import-data" // optional; if exporting to Terra which URL should we use?
  },
  "fileExplorerConfig": { // optional; configuration for the File Explorer
    "charts": { // optional; indicates which charts to display in the File Explorer
      "data_type": { // required; GraphQL field to query for a chart (ex: this one will display a bar chart for data types of the files in the cohort)
        "chartType": "stackedBar", // required; chart type of stack bar
        "title": "File Type" // required; title of chart
      },
      "data_format": {
        "chartType": "stackedBar",
        "title": "File Format"
      }
    },
    "filters": { // required; details facet configuration for the File Explorer
      "tabs": [ // required; divides facets into tabs
        {
          "title": "File", // required; title of the tab
          "fields": [ // required; GraphQL fields (node attributes) to list out facets
            "project_id",
            "data_type",
            "data_format"
          ]
        }
      ]
    },
    "table": { // required; configuration for File Explorer table
      "enabled": true, // required; indicates if the table should be enabled by default
      "fields": [ // required; fields (node attributes) to include to be displayed in the table
        "project_id",
        "file_name",
        "file_size",
        "object_id"
      ]
    },
    "guppyConfig": { // required; how to configure Guppy to work with the File Explorer
      "dataType": "file", // required; must match the index “type” in the guppy configuration block in the manifest.json
      "fieldMapping": [ // optional; a way to rename GraphQL fields to be more human readable
        { "field": "object_id", "name": "GUID" } // required; the file index should always include this one
      ],
      "nodeCountTitle": "Files", // required; plural of root node
      "manifestMapping": { // optional; how to configure the mapping between cases/subjects/participants and files. This is used to export or download files that are associated with a cohort. It is basically joining two indices on specific GraphQL fields
        "resourceIndexType": "case", // required; joining this index with the case index
        "resourceIdField": "case_id", // required; which field should is the main identifier in the other index?
        "referenceIdFieldInResourceIndex": "object_id", // required; which field should we join on in the other index?
        "referenceIdFieldInDataIndex": "object_id" // required; which field should we join on in the current index?
      },
      "accessibleFieldCheckList": ["project_id"],
      "accessibleValidationField": "project_id",
      "downloadAccessor": "object_id" // required; for downloading a file, what is the GUID? This should probably not change
    },
    "buttons": [ // required; buttons for File Explorer
      {
        "enabled": true, // required; determines if the button is enabled or disabled
        "type": "file-manifest", // required; button type - file-manifest is for downloading a manifest from the file index
        "title": "Download Manifest", // required; title of the button
        "leftIcon": "datafile", // optional; button’s left icon
        "rightIcon": "download", // optional; button’s right icon
        "fileName": "file-manifest.json", // required; name of downloaded file
      },
      {
        "enabled": true,
        "type": "export-files-to-workspace", // required; this type is for export files to the workspace from the File Explorer
        "title": "Export to Workspace",
        "leftIcon": "datafile",
        "rightIcon": "download"
      }
    ],
    "dropdowns": {} // optional; dropdown groupings for buttons
  },
  "useArboristUI": false, // optional; set true to enable arborist UI; defaults to false if absent
  "showArboristAuthzOnProfile": false, // optional; set true to list arborist resources on profile page
  "showFenceAuthzOnProfile": true, // optional; set false to not list fence project access on profile page
  "componentToResourceMapping": { // optional; configure some parts of arborist UI
    "Workspace": { // name of component as defined in this file
      "resource": "/workspace", // ABAC fields defining permissions required to see this component
      "method": "access",
      "service": "jupyterhub"
    },
    "Analyze Data": {
      "resource": "/workspace",
      "method": "access",
      "service": "jupyterhub"
    },
    "Query": {
      "resource": "/query_page",
      "method": "access",
      "service": "query_page"
    },
    "Query Data": {
      "resource": "/query_page",
      "method": "access",
      "service": "query_page"
    }
  }
}
```
## ETL Mapping File
The ETL mapping file is used to pull data from our Postgres database to our ElasticSearch database, which is used for the Data and File Explorers. The ETL mapping is based off of a root node, and at this point in time can only pull information from the root node and immediate nodes underneath it. Nested functionality is coming in the future. Below is an example ETL mapping file with inline comments (if you are looking to copy/paste a file as an example, please find one on Github as the inline comments will cause formatting issues):
```
mappings:
  - name: clinical_data_genericcommons // name of ElasticSearch index
    doc_type: case // doc type of index - can be whatever but must match what is in the guppy config in the manifest.json
    type: aggregator
    root: case // root node in Postgres
    props: // attributes on the root node to include in ETL
      - name: submitter_id
      - name: project_id
    flatten_props: // nodes underneath the root node to include
      - path: demographics // node underneath the root node. Must be the “backref” name of the node (example here)
        props: // attributes on this node to include
          - name: gender
          - name: race
          - name: ethnicity
          - name: year_of_birth
    aggregated_props: // used to get aggregate statistics of nested nodes
      - name: _samples_count // gets the count of this node name
        path: samples // path to this node from the root
        fn: count
      - name: _aliquots_count
        path: samples.aliquots // because this path starts with “samples”, the “samples” count block occurred first in this file
        fn: count
      - name: _read_groups_count
        path: samples.aliquots.read_groups
        fn: count
      - name: _submitted_aligned_reads_count
        path: samples.aliquots.read_groups.submitted_aligned_reads_files
        fn: count
    joining_props: // this is used to join two indices, most commonly, to get all the files associated with a cohort of cases
      - index: file // the index to join on
        join_on: case_id // the identifier to join on
        props: // attributes from this new index to pull into the ETL
          - name: data_format
            src: data_format
            fn: set
          - name: data_type
            src: data_type
            fn: set
  - name: file_genericcommons // another index
    doc_type: file // can be anything but must match guppy config
    type: collector
    root: None
    Props: // properties to collect from files
      - name: object_id
      - name: md5sum
      - name: file_name
      - name: file_size
      - name: data_format
      - name: data_type
      - name: state
    injecting_props:
      case:
        props:
          - name: case_id
            src: id
          - name: project_id
```
## Manifest File
The `manifest.json` file is used to indicate versions of our services to deploy for a specific commons, as well as any additional configuration for these services. This has been shortened to only include relevant UI pieces, please see an example of a full manifest here.
```
{
  "notes": [ … ],
  "jenkins": {...},
  "versions": { // lists all the versions of services for this commons
    "arborist": "quay.io/cdis/arborist:2.0.6", // for auth
    "aws-es-proxy": "abutaha/aws-es-proxy:0.8",
    "fence": "quay.io/cdis/fence:4.2.2", // for auth
    "indexd": "quay.io/cdis/indexd:2.0.0", // for indexing
    "peregrine": "quay.io/cdis/peregrine:1.3.0", // for queries
    "pidgin": "quay.io/cdis/pidgin:1.0.0", // for queries
    "revproxy": "quay.io/cdis/nginx:1.15.5-ctds",
    "sheepdog": "quay.io/cdis/sheepdog:1.1.10", // for submission
    "portal": "quay.io/cdis/data-portal:2.17.0", // for UI
    "fluentd": "fluent/fluentd-kubernetes-daemonset:v1.2-debian-cloudwatch",
    "spark": "quay.io/cdis/gen3-spark:1.0.0", // for the ETL
    "tube": "quay.io/cdis/tube:0.3.9", // for the ETL
    "guppy": "quay.io/cdis/guppy:0.3.0", // for queries
    "sower": "quay.io/cdis/sower:0.3.0", // for job dispatching
    "hatchery": "quay.io/cdis/hatchery:0.1.0", // for workspaces
    "ambassador": "quay.io/datawire/ambassador:0.60.3", // for job dispatching
    "wts": "quay.io/cdis/workspace-token-service:0.2.0", // for workspaces
    "manifestservice": "quay.io/cdis/manifestservice:0.2.0" // for workspaces
  },
  "arborist": {...},
  "sower": [...],
  "hatchery": {...},
  "jupyterhub": {...},
  "canary": {...},
  "guppy": { // guppy configuration for Data and File Explorers
    "indices": [
      {
        "index": "clinical_genericcommons", // must match etlMapping index name
        "type": "case" // must match etlMapping doc_type
      },
      {
        "index": "file_genericcommons", // must match etlMapping index name

        "type": "file" // must match etlMapping doc_type

      }
    ],
    "auth_filter_field": "auth_resource_path" // used for authorization, shouldn’t change
  }

  "global": {
…
// if using tiered access
"tier_access_level": "regular", // makes the explorer aggregate information visible to unauthorized users
"tier_access_limit": 50, // determines how far down an unauthorized user can filter cases down
"public_datasets": true // makes the commons’ homepage charts public
   },
 }
```
