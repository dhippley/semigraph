#!/usr/bin/env elixir

# Simple Benchmark Without Dependencies
# ====================================
#
# This tests core Elixir/Erlang performance without loading Semigraph
# to ensure our benchmarking infrastructure works.

defmodule SimpleBenchmark do
  def run do
    IO.puts("🧪 Simple Performance Test")
    IO.puts("=" <> String.duplicate("=", 30))
    IO.puts("")

    benchmark_basic_operations()
    benchmark_ets_operations()
    benchmark_process_operations()

    IO.puts("\n✅ Simple Benchmark Complete!")
  end

  defp benchmark_basic_operations do
    IO.puts("⚡ Basic Elixir Operations")
    IO.puts("-" <> String.duplicate("-", 25))

    # List operations
    {time_us, _result} = :timer.tc(fn ->
      1..10000 |> Enum.map(&(&1 * 2)) |> Enum.sum()
    end)

    list_time_ms = time_us / 1000
    ops_per_sec = 10000 / (list_time_ms / 1000)
    IO.puts("  List map+sum (10k items): #{Float.round(list_time_ms, 2)}ms (#{Float.round(ops_per_sec, 0)} ops/sec)")

    # Map operations
    {time_us, _result} = :timer.tc(fn ->
      map = Enum.reduce(1..1000, %{}, fn i, acc ->
        Map.put(acc, "key_#{i}", i * 10)
      end)

      Enum.reduce(1..1000, 0, fn i, acc ->
        acc + Map.get(map, "key_#{i}", 0)
      end)
    end)

    map_time_ms = time_us / 1000
    map_ops_per_sec = 1000 / (map_time_ms / 1000)
    IO.puts("  Map create+lookup (1k items): #{Float.round(map_time_ms, 2)}ms (#{Float.round(map_ops_per_sec, 0)} ops/sec)")

    IO.puts("")
  end

  defp benchmark_ets_operations do
    IO.puts("🗃️  ETS Operations")
    IO.puts("-" <> String.duplicate("-", 15))

    # Create ETS table
    table = :ets.new(:test_table, [:set, :public])

    # Insert benchmark
    {time_us, _result} = :timer.tc(fn ->
      Enum.each(1..1000, fn i ->
        :ets.insert(table, {"key_#{i}", %{id: i, value: i * 10}})
      end)
    end)

    insert_time_ms = time_us / 1000
    insert_ops_per_sec = 1000 / (insert_time_ms / 1000)
    IO.puts("  Insert 1000 records: #{Float.round(insert_time_ms, 2)}ms (#{Float.round(insert_ops_per_sec, 0)} ops/sec)")

    # Lookup benchmark
    {time_us, _results} = :timer.tc(fn ->
      Enum.map(1..1000, fn i ->
        :ets.lookup(table, "key_#{i}")
      end)
    end)

    lookup_time_ms = time_us / 1000
    lookup_ops_per_sec = 1000 / (lookup_time_ms / 1000)
    IO.puts("  Lookup 1000 records: #{Float.round(lookup_time_ms, 2)}ms (#{Float.round(lookup_ops_per_sec, 0)} ops/sec)")

    # List all benchmark
    {time_us, _results} = :timer.tc(fn ->
      :ets.tab2list(table)
    end)

    list_time_ms = time_us / 1000
    IO.puts("  List all records: #{Float.round(list_time_ms, 2)}ms")

    # Cleanup
    :ets.delete(table)

    IO.puts("")
  end

  defp benchmark_process_operations do
    IO.puts("🔄 Process Operations")
    IO.puts("-" <> String.duplicate("-", 20))

    # Spawn processes benchmark
    {time_us, pids} = :timer.tc(fn ->
      Enum.map(1..100, fn _i ->
        spawn(fn ->
          # Simulate some work
          Enum.sum(1..100)
          receive do
            :stop -> :ok
          after
            1000 -> :timeout
          end
        end)
      end)
    end)

    spawn_time_ms = time_us / 1000
    spawn_ops_per_sec = 100 / (spawn_time_ms / 1000)
    IO.puts("  Spawn 100 processes: #{Float.round(spawn_time_ms, 2)}ms (#{Float.round(spawn_ops_per_sec, 0)} ops/sec)")

    # Message passing benchmark
    {time_us, _result} = :timer.tc(fn ->
      Enum.each(pids, fn pid ->
        send(pid, :stop)
      end)
    end)

    message_time_ms = time_us / 1000
    message_ops_per_sec = 100 / (message_time_ms / 1000)
    IO.puts("  Send 100 messages: #{Float.round(message_time_ms, 2)}ms (#{Float.round(message_ops_per_sec, 0)} ops/sec)")

    IO.puts("")
  end
end

# Memory usage helper
print_memory_usage = fn ->
  memory = :erlang.memory()
  total_mb = memory[:total] / 1024 / 1024
  processes_mb = memory[:processes] / 1024 / 1024
  system_mb = memory[:system] / 1024 / 1024

  IO.puts("💾 Memory Usage:")
  IO.puts("  Total: #{Float.round(total_mb, 1)} MB")
  IO.puts("  Processes: #{Float.round(processes_mb, 1)} MB")
  IO.puts("  System: #{Float.round(system_mb, 1)} MB")
  IO.puts("")
end

IO.puts("Starting benchmark...")
print_memory_usage.()

SimpleBenchmark.run()

print_memory_usage.()
