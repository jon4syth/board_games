defmodule BoardGamesWeb.SternhalmaView do
  @moduledoc """
  Functions that are intended to be called from templates to
  help render content, CSS, etc.
  """

  use BoardGamesWeb, :view

  alias BoardGames.{
    Marble,
    GameState,
    BoardLocation,
    SternhalmaAdapter
  }

  @board_size 465
  @min_x -0.39230484541326227
  @max_x 20.392304845413264
  @max_x 23
  @min_y 0
  @max_y 27

  @spec format_countdown(integer()) :: String.t()
  def format_countdown(seconds) do
    formatted_seconds =
      (seconds - 10)
      |> abs()
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "00:#{formatted_seconds}"
  end

  @spec player_styles(GameState.t(), String.t()) :: String.t()
  def player_styles(game, player) do
    bg_color = background_color(game.marble_colors, player)

    [
      "--bgc:#{bg_color}",
      "--bc:#{color(game.marble_colors, player)}"
    ]
    |> Enum.join(";")
  end

  @spec player_classes(GameState.t(), String.t()) :: String.t()
  def player_classes(game, player) do
    is_turn = game.status == :playing and game.turn == player

    ["player-marble"]
    |> add_if(fn -> "highlight" end, is_turn)
    |> Enum.join(" ")
  end

  @spec marble_css_classes(GameState.t(), String.t(), String.t(), BoardLocation.t(), Marble.t()) ::
          String.t()
  def marble_css_classes(game, marble_owner, player_name, start, marble) do
    is_turn = game.status == :playing and game.turn == player_name
    last_path = game.last_move

    marble_position = SternhalmaAdapter.board_position({marble.x, marble.y})

    path_includes_marble? =
      last_path != nil and
        Enum.any?(last_path, fn location -> location.grid_position == marble_position end)

    ["marble"]
    |> add_if(fn -> "clicked" end, is_turn and marble_owner == player_name and start == nil)
    |> add_if(fn -> "glow" end, start != nil and start.grid_position == marble_position)
    |> add_if(fn -> "path" end, path_includes_marble?)
    |> Enum.join(" ")
  end

  @spec marble_styles(Marble.t(), list(String.t()), String.t(), list(BoardLocation.t())) ::
          String.t()
  def marble_styles(marble, players, player_name, last_path) do
    {left, bottom} = normalize({marble.x, marble.y})
    marble_position = SternhalmaAdapter.board_position({marble.x, marble.y})

    step_index = compute_step_index(last_path, marble_position)

    [
      "--left:#{left}px",
      "--bottom:#{bottom}px",
      "--bgc:#{marble.bg_color}",
      "--bc:#{marble.border_color}",
      "--rotation: #{rotate(players, player_name) * -1}deg",
      "color: #{text_color(marble.bg_color)}"
    ]
    |> add_if(fn -> "--path-step: \"#{step_index}\"" end, step_index != nil)
    |> Enum.join(";")
  end

  @spec board_cell_css_classes(
          GameState.t(),
          String.t(),
          BoardLocation.t(),
          BoardLocation.t(),
          list(BoardLocation.t())
        ) :: String.t()
  def board_cell_css_classes(game, player_name, start, board_location, last_path) do
    is_turn? = game.turn == player_name and game.status == :playing

    path_includes_cell? =
      last_path != nil and
        Enum.any?(last_path, fn location ->
          location.grid_position == board_location.grid_position
        end)

    ["board-cell"]
    |> add_if(fn -> "clicked" end, is_turn? and start != nil)
    |> add_if(fn -> "path" end, path_includes_cell?)
    |> Enum.join(" ")
  end

  @spec board_cell_styles(
          BoardLocation.t(),
          list(String.t()),
          String.t(),
          list(BoardLocation.t())
        ) :: String.t()
  def board_cell_styles(board_location, players, player_name, last_path) do
    {left, bottom} = normalize(board_location.screen_position)

    step_index =
      Enum.find_index(last_path, fn location ->
        location.grid_position == board_location.grid_position
      end)

    [
      "--left:#{left}px",
      "--bottom:#{bottom}px",
      "--rotation: #{rotate(players, player_name) * -1}deg",
      "color: #ffffff"
    ]
    |> add_if(fn -> "--path-step: \"#{step_index + 1}\"" end, step_index != nil)
    |> Enum.join(";")
  end

  @spec background_color(map(), String.t()) :: String.t()
  def background_color(colors, player_name) do
    color_helper(colors, player_name)
    |> Enum.at(0)
  end

  @spec color(map(), String.t()) :: String.t()
  def color(colors, player_name) do
    color_helper(colors, player_name)
    |> Enum.at(1)
  end

  @spec add_if(list(term()), term(), boolean()) :: list(term())
  defp add_if(items, _item, false) do
    items
  end

  defp add_if(items, item, true) do
    [item.() | items]
  end

  @spec compute_step_index(list(BoardLocation.t()), BoardLocation.grid_position()) ::
          nil | non_neg_integer()
  defp compute_step_index(path, _marble_position) when path == nil or length(path) == 0, do: nil

  defp compute_step_index(path, marble_position) do
    final_position = List.last(path).grid_position

    compute_step_index(final_position, marble_position, length(path))
  end

  @spec compute_step_index(
          BoardLocation.grid_position(),
          BoardLocation.grid_position(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp compute_step_index(final_position, marble_position, path_length)
       when final_position == marble_position,
       do: path_length

  defp compute_step_index(_final_position, _marble_position, _path_length), do: nil

  @spec text_color(String.t()) :: String.t()
  defp text_color(<<"#", hex_color::binary>>) do
    with {:ok, <<red, green, blue>>} <- Base.decode16(hex_color, case: :mixed) do
      if red * 0.299 + green * 0.587 + blue * 0.114 > 186 do
        "#000000"
      else
        "#ffffff"
      end
    else
      _ ->
        # default to black
        "#000000"
    end
  end

  @spec rotate(list(String.t()), String.t()) :: non_neg_integer()
  def rotate(players, player_name) do
    players
    |> Enum.reverse()
    |> Enum.find_index(&(&1 == player_name))
    |> rotation()
  end

  @spec rotation(non_neg_integer()) :: non_neg_integer()
  defp rotation(0), do: 180
  defp rotation(1), do: 0
  defp rotation(2), do: 240
  defp rotation(3), do: 60
  defp rotation(4), do: 120
  defp rotation(5), do: 300
  defp rotation(_player_index), do: 0

  @spec color_helper(map(), String.t()) :: list({String.t(), String.t()})
  defp color_helper(colors, player_name) do
    colors
    |> Map.get(player_name)
    |> Tuple.to_list()
  end

  @spec normalize({number(), number()}) :: {integer(), integer()}
  defp normalize({x, y}) do
    # Fit 2d point within a box of a dimension represented by size

    # center
    x = x - (@max_x - @min_x) / 2
    y = y - (@max_y - @min_y) / 2

    # scale
    scale = max(@max_x - @min_x, @max_y - @min_y)
    x = x / scale * @board_size + 12
    y = y / scale * @board_size - 10

    x = round(x + @board_size / 2)
    y = round(y + @board_size / 2)

    {x, y}
  end
end
