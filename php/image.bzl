load("@aspect_bazel_lib//lib:tar.bzl", "tar")
load("@rules_distroless//distroless:defs.bzl", "group", "passwd")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_push")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files", "strip_prefix")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//:transition.bzl", "multi_arch")

PHP_MODULES = {
    "common": {
        "10": ["pdo"],
        "20": [
            "calendar",
            "ctype",
            "exif",
            "ffi",
            "fileinfo",
            "ftp",
            "gettext",
            "iconv",
            "phar",
            "posix",
            "shmop",
            "sockets",
            "sysvmsg",
            "sysvem",
            "sysvshm",
            "tokenizer",
        ],
    },
    "opcache": {
        "10": ["opcache"],
    },
    "xml": {
        "15": ["xml"],
        "20": [
            "dom",
            "simplexml",
            "xmlreader",
            "xmlwriter",
            "xsl",
        ],
    },
    "mysql": {
        "10": ["mysqlnd"],
        "20": ["mysqli", "pdo_mysql"],
    },
    "intl": {
        "20": ["intl"],
    },
    "gd": {
        "20": ["gd"],
    },
    "zip": {
        "20": ["zip"],
    },
    "json": {
        "20": ["json"],
    },
}

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

    pkg_files(
        name = "{}_fpm-config".format(version),
        srcs = [":www.conf"],
        prefix = "etc/php/{}/fpm/pool.d".format(version),
        strip_prefix = strip_prefix.from_pkg(),
    )

    pkg_tar(
        name = "{}_fpm-config.tar".format(version),
        srcs = [":{}_fpm-config".format(version)],
    )

    tar(
        name = name + "_sh",
        mtree = ["./bin/php type=link link=/usr/bin/php{}".format(version)] +
                [
                    "./etc/php/{}/{}/conf.d/{}-{}.ini type=link link=/usr/share/php{}-{}/{}/{}.ini".format(version, engine, priority, mod, version, pkg, pkg, mod)
                    for pkg in PHP_MODULES
                    for priority in PHP_MODULES[pkg]
                    for mod in PHP_MODULES[pkg][priority]
                    for engine in ["cli", "fpm"]
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
            "@php-{}-bookworm//:flat".format(version),
            ":{}_sh".format(name),
            ":{}_passwd".format(name),
            ":{}_group".format(name),
            ":{}_fpm-config.tar".format(version),
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
