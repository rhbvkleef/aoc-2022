import { readdirSync, readFileSync } from "fs";
import { join as joinPath } from "path";

import { List } from "./gleam.mjs";

export function find_modules(subpath) {
    return List.fromArray(do_find_modules(subpath));
}

function do_find_modules(subpath) {
    let packageName = readRootPackageName();
    let dist = `../../${packageName}/dist/`;

    const result = []

    for (let path of gleamFiles("src/" + subpath)) {
        let js_path = path.slice("src/".length).replace(".gleam", ".mjs");
        result.push(joinPath(dist, js_path));
    }

    return result;
}

/**
 * 
 * @param {string} module 
 * @param {string} func 
 * @param {any[]} args 
 */
export async function apply(module, func, args) {
    const the_module = await import(module);

    return await new Promise(function(resolve, error) {
        resolve(the_module[func](...args));
    });
};

export async function promise_of(fun) {
    return fun()
}

function* gleamFiles(directory) {
    let dirents = readdirSync(directory, { withFileTypes: true });
    for (let dirent of dirents) {
        let path = joinPath(directory, dirent.name);
        if (dirent.isDirectory()) {
            yield* gleamFiles(path);
        } else if (path.endsWith(".gleam")) {
            yield path;
        }
    }
}

function readRootPackageName() {
    let toml = readFileSync("gleam.toml", "utf-8");
    for (let line of toml.split("\n")) {
        let matches = line.match(/\s*name\s=\s"([a-z0-9_]+)"/);
        if (matches) return matches[1];
    }
    throw new Error("Could not determine package name from gleam.toml");
}
