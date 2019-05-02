import csv


def get_fileinfo_list_from_csv_manifest(manifest_file, start=None, end=None, dem="\t"):
    """
    get file info from csv manifest
    """
    files = []
    headers = []
    with open(manifest_file, "rt") as csvfile:
        csvReader = csv.DictReader(csvfile, delimiter=dem)
        headers = csvReader.fieldnames

        for row in csvReader:
            row["size"] = int(row["size"])
            files.append(row)

    start_idx = start if start else 0
    end_idx = end if end else len(files)

    return files[start_idx:end_idx], headers


def write_csv(filename, files, sorted_attr=None, fieldnames=None):
    def on_key(element):
        return element[sorted_attr]
    if sorted_attr:
        sorted_files = sorted(files, key=on_key)
    else:
        sorted_files = files

    if not files:
        return
    fieldnames = fieldnames or files[0].keys()
    with open(filename, mode="w") as outfile:
        writer = csv.DictWriter(outfile, delimiter="\t", fieldnames=fieldnames)
        writer.writeheader()

        for f in sorted_files:
            writer.writerow(f)