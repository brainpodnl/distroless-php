load("@aspect_bazel_lib//lib:tar.bzl", "tar")
load("@rules_distroless//distroless:defs.bzl", "group", "passwd")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_push")
load("//:transition.bzl", "multi_arch")

def php_fpm_image(name, version):
    passwd(
        name = name + "_passwd",
        entries = [{
            "uid": 100,
            "gid": 65534,
            "home": "/var/www",
            "shell": "/usr/sbin/nologin",
            "username": "www-data",
        }],
    )

    group(
        name = name + "_group",
        entries = [{
            "name": "www-data",
            "gid": 65534,
        }],
    )

    tar(
        name = name + "_sh",
        mtree = [
            "./bin/php type=link link=/usr/bin/php{}".format(version),
            "./var/log/php{}-fpm.log type=link link=/dev/stderr".format(version),
            "./run/php/php{}-fpm.sock type=file".format(version),
            "./run/php/php-fpm.sock type=link link=/run/php/php{}-fpm.sock".format(version),
        ],
    )

    oci_image(
        name = name,
        architecture = select({
            "@platforms//cpu:arm64": "arm64",
            "@platforms//cpu:x86_64": "amd64",
        }),
        cmd = ["-F"],
        entrypoint = ["/usr/sbin/php-fpm" + version],
        os = "linux",
        tags = ["manual"],
        tars = [
            ":{}_sh".format(name),
            ":{}_passwd".format(name),
            ":{}_group".format(name),
            "@php-{}-bookworm//:flat".format(version),
        ],
    )

    multi_arch(
        name = name + "_images",
        image = ":" + name,
        platforms = [
            "//:linux-arm64",
            "//:linux-amd64",
        ],
    )

    oci_image_index(
        name = name + "_index",
        images = [":{}_images".format(name)],
    )

    oci_push(
        name = name + "_push",
        image = ":{}_index".format(name),
        remote_tags = [version],
        repository = "php-fpm",
    )
