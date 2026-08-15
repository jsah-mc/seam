{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;

    nixpkgs = {
      source = pkgs.path;
      config.allowUnfree = true;
    };

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    opts = {
      expandtab = true;
      ignorecase = true;
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      signcolumn = "yes";
      smartcase = true;
      smartindent = true;
      tabstop = 2;
      termguicolors = true;
      updatetime = 250;
    };

    clipboard.providers.wl-copy.enable = true;

    keymaps = [
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Live grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Oil<cr>";
        options.desc = "File explorer";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Diagnostics";
      }
    ];

    plugins = {
      avante = {
        enable = true;
        settings = {
          provider = "openai";
          auto_suggestions_provider = "openai";
          providers.openai = {
            endpoint = "https://api.openai.com/v1";
            model = "gpt-4o";
            timeout = 30000;
            extra_request_body = {
              temperature = 0;
              max_tokens = 4096;
            };
          };
          behaviour = {
            auto_suggestions = false;
            auto_set_highlight_group = true;
            auto_set_keymaps = true;
            support_paste_from_clipboard = true;
          };
          mappings = {
            ask = "<leader>aa";
            edit = "<leader>ae";
            refresh = "<leader>ar";
            toggle.default = "<leader>at";
          };
          windows = {
            position = "right";
            width = 35;
            wrap = true;
          };
        };
      };

      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default";
          completion.documentation.auto_show = true;
          sources = {
            default = [
              "lsp"
              "path"
              "snippets"
              "buffer"
            ];
          };
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms = 1000;
            lsp_format = "fallback";
          };
          formatters_by_ft = {
            bash = [ "shfmt" ];
            css = [ "prettierd" ];
            html = [ "prettierd" ];
            javascript = [ "prettierd" ];
            javascriptreact = [ "prettierd" ];
            json = [ "prettierd" ];
            lua = [ "stylua" ];
            markdown = [ "prettierd" ];
            nix = [ "nixpkgs_fmt" ];
            python = [
              "isort"
              "black"
            ];
            sh = [ "shfmt" ];
            toml = [ "taplo" ];
            typescript = [ "prettierd" ];
            typescriptreact = [ "prettierd" ];
            yaml = [ "prettierd" ];
          };
        };
      };

      copilot-lua = {
        enable = true;
        settings = {
          panel.enabled = false;
          suggestion.enabled = false;
        };
      };

      gitsigns.enable = true;
      lsp = {
        enable = true;
        inlayHints = true;
        keymaps = {
          silent = true;
          diagnostic = {
            "[d" = "goto_prev";
            "]d" = "goto_next";
          };
          lspBuf = {
            "K" = "hover";
            "gd" = "definition";
            "gD" = "references";
            "gi" = "implementation";
            "gr" = "rename";
          };
        };
        servers = {
          bashls.enable = true;
          clangd.enable = true;
          cssls.enable = true;
          gopls.enable = true;
          html.enable = true;
          jsonls.enable = true;
          lua_ls.enable = true;
          marksman.enable = true;
          nil_ls.enable = true;
          pyright.enable = true;
          ruff.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };
          taplo.enable = true;
          ts_ls.enable = true;
          yamlls.enable = true;
        };
      };
      lsp-format.enable = true;
      lsp-lines.enable = true;
      lsp-signature.enable = true;
      lualine.enable = true;
      nix.enable = true;
      oil.enable = true;
      sidekick.enable = true;
      telescope.enable = true;
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };
      trouble.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;
    };
  };
}
