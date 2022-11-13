import gleam/dynamic.{Dynamic}

pub type Arguments =
  List(Dynamic)

pub type InvocationError {
  ModuleNotFound(Module)
  FunctionNotFound(Module, Function, Arity)
  InvocationTargetError(Panic)
}

if javascript {
  import gleam/list
  import gleam/result
  import gleam/string
  import gleam/javascript/promise
  import gleam/javascript/array

  pub type Promise(return, error) =
    promise.Promise(Result(return, error))

  pub external type Panic

  pub type Module =
    String

  pub type Function =
    String

  pub type Arity =
    Int

  pub fn apply(
    module: Module,
    function: Function,
    arguments: Arguments,
  ) -> Promise(Dynamic, InvocationError) {
    do_apply(module, function, array.from_list(arguments))
    |> promise.map(fn(result) { Ok(result) })
  }

  pub fn format_function_name(function: Function) -> String {
    function
  }

  pub fn format_module_name(module: Module) -> String {
    string.split(module, on: "/")
    |> list.drop(up_to: 5)
    |> string.join(with: "/")
    |> string.split(on: ".")
    |> list.first()
    |> result.unwrap(or: "???")
  }

  pub fn then(
    promise: Promise(data, err),
    function: fn(data) -> Promise(new_data, err),
  ) -> Promise(new_data, err) {
    promise.then_try(promise, function)
  }

  pub fn except(
    promise: Promise(data, err),
    callback: fn(err) -> Promise(data, new_err),
  ) -> Promise(data, new_err) {
    promise.then(
      promise,
      fn(result) {
        case result {
          Ok(data) -> promise.resolve(Ok(data))
          Error(err) -> callback(err)
        }
      },
    )
  }

  pub fn await(_: Promise(data, error)) -> Nil {
    Nil
  }

  pub external fn of(
    function: fn() -> Result(data, error),
  ) -> promise.Promise(Result(data, error)) =
    "../aoc@invoke_ffi.mjs" "promise_of"

  external fn do_apply(
    Module,
    Function,
    array.Array(Dynamic),
  ) -> promise.Promise(Dynamic) =
    "../aoc@invoke_ffi.mjs" "apply"

  pub external fn find_modules(String) -> List(Module) =
    "../aoc@invoke_ffi.mjs" "find_modules"
}

if erlang {
  import gleam/list
  import gleam/result
  import gleam/string
  import gleam/erlang.{Crash}
  import gleam/erlang/atom.{Atom}

  pub external type Promise(return, error)

  pub type Panic =
    Crash

  pub type Module =
    Atom

  pub type Function =
    Atom

  pub type Arity =
    Int

  pub fn apply(
    module: Module,
    function: Function,
    arguments: Arguments,
  ) -> Promise(Dynamic, InvocationError) {
    ffi_promise_of(fn() {
      case ffi_do_ensure_loaded(module) {
        False -> Error(ModuleNotFound(module))
        True ->
          case
            d_erlang__function_exported(
              module,
              function,
              list.length(arguments),
            )
          {
            False ->
              Error(FunctionNotFound(module, function, list.length(arguments)))
            True ->
              case
                erlang.rescue(fn() {
                  d_erlang__apply(module, function, arguments)
                })
              {
                Ok(result) -> Ok(result)
                Error(crash) -> Error(InvocationTargetError(crash))
              }
          }
      }
    })
  }

  pub fn format_function_name(function: Function) -> String {
    atom.to_string(function)
  }

  pub fn format_module_name(module: Module) -> String {
    atom.to_string(module)
    |> string.split(on: "@")
    |> list.drop(up_to: 1)
    |> list.first()
    |> result.unwrap(or: "")
  }

  pub fn then(
    promise: Promise(data, err),
    function: fn(data) -> Promise(new_data, err),
  ) -> Promise(new_data, err) {
    ffi_map(
      promise,
      fn(result) {
        case result {
          Ok(ok) -> ffi_await(function(ok))
          Error(error) -> Error(error)
        }
      },
    )
  }

  pub fn except(
    promise: Promise(data, err),
    function: fn(err) -> Promise(data, new_err),
  ) -> Promise(data, new_err) {
    ffi_map(
      promise,
      fn(result) {
        case result {
          Ok(ok) -> Ok(ok)
          Error(error) -> ffi_await(function(error))
        }
      },
    )
  }

  pub fn of(function: fn() -> Result(data, error)) -> Promise(data, error) {
    ffi_promise_of(function)
  }

  pub fn await(promise: Promise(data, error)) -> Nil {
    let _ = ffi_await(promise)
    Nil
  }

  pub fn find_modules(subpath: String) -> List(Module) {
    ffi_find_files(
      matching: "**/*.{erl,gleam}",
      in: string.append("src/", subpath),
    )
    |> list.map(gleam_to_erlang_module_name(subpath, _))
    |> list.map(atom.from_string)
    |> result.values()
  }

  fn gleam_to_erlang_module_name(path: String, name: String) -> String {
    name
    |> string.replace(".gleam", "")
    |> string.replace(".erl", "")
    |> string.append(string.append(path, "/"), _)
    |> string.replace("/", "@")
  }

  external fn ffi_do_ensure_loaded(module: Module) -> Bool =
    "aoc@invoke_ffi" "do_ensure_loaded"

  external fn ffi_find_files(matching: String, in: String) -> List(string) =
    "aoc@invoke_ffi" "find_files"

  external fn ffi_promise_of(
    worker: fn() -> Result(result, error),
  ) -> Promise(result, error) =
    "aoc@invoke_ffi" "promise_of"

  external fn ffi_map(
    promise: Promise(result, error),
    worker_factory: fn(Result(result, error)) -> Result(result2, error2),
  ) -> Promise(result2, error2) =
    "aoc@invoke_ffi" "map"

  external fn ffi_await(worker: Promise(result, error)) -> Result(result, error) =
    "aoc@invoke_ffi" "await"

  external fn d_erlang__apply(
    module: Module,
    function: Function,
    arguments: Arguments,
  ) -> Dynamic =
    "erlang" "apply"

  external fn d_erlang__function_exported(Module, Function, Arity) -> Bool =
    "erlang" "function_exported"
}
