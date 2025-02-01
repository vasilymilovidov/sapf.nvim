# sapf.nvim
A Neovim plugin for interacting with [sapf](https://github.com/lfnoise/sapf).

## Commands 
- `:SapfStart` - Start sapf.
- `:SapfKill` - Kill sapf.
- `:SapfStop` - Send stop to sapf.
- `:SapfClear` - Send clear to sapf.
- `:SapfEvalParagraph` - Evaluate the current paragraph.
- `:SapfStopAndEval` - Send rtop and evaluate the current paragraph.
- `:SapfRunMultiple` - Evaluate multiple paragraphs.
- `:SapfFunctionHelp` - Get help for the function under the cursor.

## Config with LazyVim
```lua
{
    "vasilymilovidov/sapf.nvim",
    config = function()
      require("sapf").setup({
        interpreter = "sapf", -- path to sapf
        debug = false,
        window = {
          width = 0.4,
        },
      })
    end,
    keys = {
      { "<leader>on", "<cmd>SapfStart<cr>", desc = "Start Sapf" },
      { "<leader>ok", "<cmd>SapfKill<cr>", desc = "Kill Sapf" },
      { "<leader>os", "<cmd>SapfStop<cr>", desc = "Send Stop Message" },
      { "<leader>oc", "<cmd>SapfClear<cr>", desc = "Send Clear Message" },
      { "<leader>oe", "<cmd>SapfEvalParagraph<cr>", desc = "Evaluate Paragraph" },
      { "<leader>om", "<cmd>SapfRunMultiple<cr>", desc = "Run Multiple Paragraphs" },
      { "<leader>or", "<cmd>SapfStopAndEval<cr>", desc = "Send Stop and Reeval" },
      { "<leader>oh", "<cmd>SapfFunctionHelp<cr>", desc = "Function Help" },
    },
  }
```