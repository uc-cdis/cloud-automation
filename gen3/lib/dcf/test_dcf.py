import os
import aws_refresh_report
import google_refresh_report
import redaction


current_path = os.path.dirname(os.path.abspath(__file__))

aws_log_file = current_path + "/testData/aws/GDC_sample_manifest.txt"
gs_log_dir = current_path + "/testData/google/active"
validation_log = current_path + "/testData/validation.log"

manifest = current_path + "/testData/GDC_sample_manifest.tsv"
redaction_manifest = current_path + "/testData/GDC_sample_redact_manifest.tsv"
aws_redact_log = current_path + "/testData/aws/aws_deletion_log.json"
gs_redact_log = current_path + "/testData/google/gs_deletion_log.json"

def test_aws_report():
    report = aws_refresh_report.aws_refresh_report(manifest, aws_log_file)
    assert report == """
    Number of files need to be copied 9. Total 0 (GiB)
    Number of files were copied successfully via aws cli 3. Total 0.029831038787961006(GiB)
    Number of files were copied successfully via gdc api 4. Total 0.00017742160707712173(GiB)
    """

def test_google_report():
    report = google_refresh_report.google_refresh_report(manifest, gs_log_dir)
    assert report ==  """
    Number of files need to be copied 9. Total 6.132916929200292(GiB)
    Number of files were copied successfully 7. Total copied data 0.030008460395038128(GiB)
    """

def test_aws_validation():
    assert aws_refresh_report.aws_refresh_validate(validation_log) == False

def test_gs_validation():
    assert google_refresh_report.google_refresh_validate(validation_log) == True

def test_redact():
    assert redaction.redaction(redaction_manifest, aws_redact_log, gs_redact_log) == """
    Total files are removed from dcf buckets 7. Total 0.030008460395038128(GiB)
    """