import sys
import json
import requests


def api_url(name, version):
    return "https://pypi.org/pypi/{}/{}/json".format(name, version)



# TODO: there is no simple way to obtain the "right" wheel
# if we don't specify the interpreter, platform and other
# additions that compose the wheel name, and the original
# idea of using only sdists doesn't quite work, because
# some packages don't assume people might create a wheel
# from a sdist.. looking at you setuptools-scm-git-archive
def extract_arguments(
        name,
        version,
        pkg_info,
        sha256=None,
        dist_type="sdist",
        # the following wheel tag components are only relevant when
        # dist_type == "bdist_wheel"
        python_tag="py2.py3",
        abi_tag="none",
        platform_tag="any"):
    try:
        releases = pkg_info['releases'][version]
    except KeyError:
        # very unlikely to happend because the api_url is configured
        # to return the version specific metadata
        raise KeyError("There is no version '{}' for the package '{}'."
                       .format(name, version))
    selected_dist = None
    ### ADHOC fix for https://github.com/Changaco/setuptools_scm_git_archive/issues/9
    ## we can't create a wheel out of the sdist for this particular project
    if name == "setuptools_scm_git_archive" and version == "1.0":
        dist_type = "bdist_wheel"
        python_tag = "py2.py3"
        abi_tag = "none"
        platform_tag = "any"
    ###
    if dist_type == "bdist_wheel":
        filename_suffix = "{python_tag}-{abi_tag}-{platform_tag}.whl".format(**{
            "python_tag": python_tag,
            "abi_tag": abi_tag,
            "platform_tag": platform_tag
        })
    else:
        filename_suffix = None
    # iterate over the available "releases", same version but different
    # distribution format
    for dist in releases:
        if dist['packagetype'] == dist_type:
            if filename_suffix is None:
                selected_dist = dist
                break
            elif dist['filename'].endswith(filename_suffix):
                selected_dist = dist
                break
            else: # not strictly necessary, but adds some clarity
                continue
    if selected_dist is None:
        raise Exception("There is no {} for {} at version {} with suffix {}"
                        .format(dist_type, name, version, filename_suffix))
    else:
        if sha256 is not None and selected_dist['digests']['sha256'] != sha256:
            raise Exception(
                "{}=={} {}: The provided hash '{}' doesn't match to the one in pypi '{}'"
                .format(
                    name, version, dist_type,
                    sha256, selected_dist['digests']['sha256']))
        return {
            'url': selected_dist['url'],
            'sha256': selected_dist['digests']['sha256']
        }




def get_arguments_for_fetchurl(name, version_and_hash, **kwargs):
    """
    Return a dictionary with the sha256 and url from pypi.

    Of the source distribution.
    """
    if "sha256:" in version_and_hash:
        version, sha256 = [
            p.strip()
            for p in version_and_hash.split(" --hash=sha256:")
        ]
    else:
        version = version_and_hash.strip()
        sha256 = None
    api_response = requests.get(api_url(name, version))
    if api_response.status_code == 200:
        return extract_arguments(name, version, api_response.json(), sha256, **kwargs)
    else:
        raise Exception(
            "Unable to obtain the information for '{}' at version '{}'. HTTP status: '{}'"
            .format(name, version, api_response.status_code))


def main():
    requires_file = sys.argv[1]
    try:
        dist_type = sys.argv[2]
    except IndexError:
        dist_type = "sdist"
    packages = {}
    with open(requires_file) as requires:
        for line in requires:
            name, version_and_hash = line.split("==")
            packages[name] = get_arguments_for_fetchurl(name, version_and_hash, dist_type=dist_type)
    print(json.dumps(packages))

if __name__ == '__main__':
    main()
