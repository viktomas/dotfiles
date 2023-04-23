return {
  'leoluz/nvim-dap-go',
    dependencies = {
      'mfussenegger/nvim-dap',
      'nvim-treesitter/nvim-treesitter',
    },
    -- opts = {},
    config = function ()
      require('dap-go').setup()
      vim.keymap.set('n', '<leader>dt', require('dap-go').debug_test, {desc = "Debug test"})
    end
}
