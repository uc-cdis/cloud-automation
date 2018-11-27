import config_helper
import os
import time
import yaml

# WORKSPACE == Jenkins workspace
TEST_ROOT = (
    os.getenv("WORKSPACE", os.getenv("XDG_RUNTIME_DIR", "/tmp"))
    + "/test_config_helper/"
    + str(int(time.time()))
)
APP_NAME = "test_config_helper"
TEST_JSON = """
{
  "a": "A",
  "b": "B",
  "c": "C"
}
"""
TEST_FILENAME = "bla.json"
config_helper.XDG_DATA_HOME = TEST_ROOT


def setup():
    test_folder = TEST_ROOT + "/gen3/" + APP_NAME
    if not os.path.exists(test_folder):
        os.makedirs(test_folder)
    with open(test_folder + "/" + TEST_FILENAME, "w") as writer:
        writer.write(TEST_JSON)


def test_find_paths():
    setup()
    path_list = config_helper.find_paths(TEST_FILENAME, APP_NAME)
    assert len(path_list) == 1
    bla_path = TEST_ROOT + "/gen3/" + APP_NAME + "/" + TEST_FILENAME
    assert os.path.exists(bla_path)
    assert path_list[0] == bla_path


def test_load_json():
    setup()
    data = config_helper.load_json(TEST_FILENAME, APP_NAME)
    for key in ["a", "b", "c"]:
        assert data[key] == key.upper()


def test_replace():
    data = (
        "top-level:" + "\n"
        "  second-level:" + "\n"
        "    some_value: '12345'" + "\n"
        "    some_other_value: '54321'" + "\n"
        "    another-level:" + "\n"
        "      nested_value: abc" + "\n"
        "  another-second-level:" + "\n"
        "     some_value: def" + "\n"
    )
    new_data = {
        "level-1": {
            "level-2": {
                "level-3": {"some_new_value": "67890", "some_other_new_value": "09876"}
            }
        }
    }

    replacement_value = config_helper._get_nested_value(
        new_data, "level-1/level-2/level-3/some_new_value"
    )

    data = config_helper._replace(
        data, "top-level/another-second-level/some_value", replacement_value
    )

    assert yaml.safe_load(data)["top-level"]["second-level"]["some_value"] == "12345"
    assert (
        yaml.safe_load(data)["top-level"]["another-second-level"]["some_value"]
        == new_data["level-1"]["level-2"]["level-3"]["some_new_value"]
    )
    assert (
        yaml.safe_load(data)["top-level"]["second-level"]["some_other_value"] == "54321"
    )
    assert (
        yaml.safe_load(data)["top-level"]["second-level"]["another-level"][
            "nested_value"
        ]
        == "abc"
    )


def test_replace_doesnt_exist():
    """
    Test that when the replacement value isn't there, we just insert an
    empty string.
    """
    data = (
        "top-level:" + "\n"
        "  second-level:" + "\n"
        "    some_value: '12345'" + "\n"
        "    some_other_value: '54321'" + "\n"
        "    another-level:" + "\n"
        "      nested_value: abc" + "\n"
        "  another-second-level:" + "\n"
        "     some_value: def" + "\n"
    )
    new_data = {}

    replacement_value = config_helper._get_nested_value(
        new_data, "level-1/level-2/level-3/some_new_value"
    )

    data = config_helper._replace(
        data, "top-level/second-level/some_value", replacement_value
    )

    assert yaml.safe_load(data)["top-level"]["second-level"]["some_value"] == ""

    assert (
        yaml.safe_load(data)["top-level"]["second-level"]["some_other_value"] == "54321"
    )
    assert (
        yaml.safe_load(data)["top-level"]["second-level"]["another-level"][
            "nested_value"
        ]
        == "abc"
    )
    assert (
        yaml.safe_load(data)["top-level"]["another-second-level"]["some_value"] == "def"
    )


def test_nothing_to_replace():
    data = ""
    new_data = {
        "level-1": {
            "level-2": {
                "level-3": {"some_new_value": "67890", "some_other_new_value": "09876"}
            }
        }
    }

    replacement_value = config_helper._get_nested_value(
        new_data, "level-1/level-2/level-3/some_new_value"
    )

    data = config_helper._replace(
        data, "top-level/second-level/some_value", replacement_value
    )

    assert data == ""


def run_tests():
    test_find_paths()
    test_load_json()
    test_replace()
    test_replace_doesnt_exist()
    test_nothing_to_replace()


if __name__ == "__main__":
    run_tests()
