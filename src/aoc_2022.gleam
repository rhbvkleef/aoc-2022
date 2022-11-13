import gleam/dynamic.{Dynamic}
import gleam/io
import gleam/list
import aoc/invoke

type Solution {
  Part1
  Part2
}

pub type Error {
  AtomDecodeError(dynamic.DecodeErrors)
  SolutionRunError(invoke.InvocationError)
}

pub fn main() {
  invoke.find_modules("solutions")
  |> list.map(run_module)
  |> list.map(fn(run_result) {
    list.map(
      run_result.1,
      fn(prom) {
        invoke.then(
          prom,
          fn(result) {
            invoke.of(fn() {
              io.print(invoke.format_module_name(run_result.0))
              io.print(": ")
              io.println(invoke.format_function_name(result.0))

              io.print("  ")
              io.debug(result.1)
              Ok(Nil)
            })
          },
        )
        |> invoke.await()
      },
    )
  })

  Nil
}

fn run_module(
  module: invoke.Module,
) -> #(invoke.Module, List(invoke.Promise(#(invoke.Function, Dynamic), Error))) {
  let prom =
    [solution_as_func_name(Part1), solution_as_func_name(Part2)]
    |> list.map(fn(v) {
      invoke.apply(module, v, [])
      |> invoke.except(fn(err) {
        invoke.of(fn() { Error(SolutionRunError(err)) })
      })
      |> invoke.then(fn(result) { invoke.of(fn() { Ok(#(v, result)) }) })
    })

  #(module, prom)
}

if erlang {
  import gleam/erlang/atom

  fn solution_as_func_name(solution: Solution) -> invoke.Function {
    case solution {
      Part1 -> atom.create_from_string("part1")
      Part2 -> atom.create_from_string("part2")
    }
  }
}

if javascript {
  fn solution_as_func_name(solution: Solution) -> invoke.Function {
    case solution {
      Part1 -> "part1"
      Part2 -> "part2"
    }
  }
}
