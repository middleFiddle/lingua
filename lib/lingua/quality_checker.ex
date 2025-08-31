defmodule Lingua.QualityChecker do
  @moduledoc """
  Quality validation and checking for AI translations.
  
  Provides basic quality metrics:
  - Length ratio validation
  - Character preservation checks  
  - Basic formatting validation
  - Placeholder/variable preservation
  """

  require Logger

  def check_translation(original, translation, _language_code) do
    checks = [
      check_length_ratio(original, translation),
      check_placeholders_preserved(original, translation), 
      check_basic_formatting(original, translation),
      check_not_empty(original, translation)
    ]
    
    # Calculate overall quality score (0.0 - 1.0)
    scores = Enum.map(checks, & &1.score)
    avg_score = Enum.sum(scores) / length(scores)
    
    quality_result = %{
      overall_score: avg_score,
      checks: checks,
      issues: Enum.filter(checks, & &1.score < 0.8)
    }
    
    if avg_score < 0.6 do
      Logger.warning("Low quality translation detected:")
      Logger.warning("  Original: #{original}")
      Logger.warning("  Translation: #{translation}")
      Logger.warning("  Score: #{Float.round(avg_score, 2)}")
      
      for issue <- quality_result.issues do
        Logger.warning("  Issue: #{issue.name} - #{issue.message}")
      end
    end
    
    quality_result
  end

  defp check_length_ratio(original, translation) do
    orig_length = String.length(original)
    trans_length = String.length(translation)
    
    ratio = if orig_length > 0 do
      trans_length / orig_length
    else
      1.0
    end
    
    # Acceptable range is 0.5x to 3.0x original length
    score = cond do
      ratio >= 0.5 and ratio <= 3.0 -> 1.0
      ratio >= 0.3 and ratio < 0.5 -> 0.7
      ratio > 3.0 and ratio <= 5.0 -> 0.7
      true -> 0.3
    end
    
    %{
      name: "length_ratio",
      score: score,
      ratio: ratio,
      message: "Translation length ratio: #{Float.round(ratio, 2)}x"
    }
  end

  defp check_placeholders_preserved(original, translation) do
    # Common placeholder patterns
    patterns = [
      ~r/\{\{[^}]+\}\}/,  # {{variable}}
      ~r/\{[^}]+\}/,      # {variable}
      ~r/%[s|d|f]/,       # %s, %d, %f
      ~r/%\{[^}]+\}/,     # %{variable}
      ~r/<[^>]+>/         # <tag>
    ]
    
    original_placeholders = extract_placeholders(original, patterns)
    translation_placeholders = extract_placeholders(translation, patterns)
    
    missing_placeholders = original_placeholders -- translation_placeholders
    extra_placeholders = translation_placeholders -- original_placeholders
    
    score = cond do
      missing_placeholders == [] and extra_placeholders == [] -> 1.0
      length(missing_placeholders) <= 1 and extra_placeholders == [] -> 0.8
      length(missing_placeholders) + length(extra_placeholders) <= 2 -> 0.6
      true -> 0.2
    end
    
    issues = []
    issues = if missing_placeholders != [], do: ["Missing: #{inspect(missing_placeholders)}"] ++ issues, else: issues
    issues = if extra_placeholders != [], do: ["Extra: #{inspect(extra_placeholders)}"] ++ issues, else: issues
    
    %{
      name: "placeholders_preserved",
      score: score,
      message: if(issues == [], do: "All placeholders preserved", else: Enum.join(issues, ", "))
    }
  end

  defp extract_placeholders(text, patterns) do
    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, text) |> List.flatten()
    end)
    |> Enum.uniq()
  end

  defp check_basic_formatting(original, translation) do
    # Check basic formatting consistency
    checks = [
      {String.starts_with?(original, " "), String.starts_with?(translation, " ")},
      {String.ends_with?(original, " "), String.ends_with?(translation, " ")},
      {String.ends_with?(original, "."), String.ends_with?(translation, ".")},
      {String.ends_with?(original, "!"), String.ends_with?(translation, "!")},
      {String.ends_with?(original, "?"), String.ends_with?(translation, "?")}
    ]
    
    matching_checks = Enum.count(checks, fn {orig, trans} -> orig == trans end)
    score = matching_checks / length(checks)
    
    %{
      name: "basic_formatting", 
      score: score,
      message: "Formatting consistency: #{matching_checks}/#{length(checks)} checks passed"
    }
  end

  defp check_not_empty(original, translation) do
    score = cond do
      String.trim(translation) == "" and String.trim(original) != "" -> 0.0
      String.trim(translation) == String.trim(original) -> 0.5  # Unchanged
      true -> 1.0
    end
    
    message = cond do
      score == 0.0 -> "Translation is empty"
      score == 0.5 -> "Translation unchanged from original"
      true -> "Translation not empty"
    end
    
    %{
      name: "not_empty",
      score: score,
      message: message
    }
  end
end