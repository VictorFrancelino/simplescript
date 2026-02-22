package cmd

import (
	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(wasmCmd)
}

var wasmCmd = &cobra.Command{
	Use: "wasm [file.ss]",
	Short: "Compile to WebAssembly (via TinyGo)",
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		filename := args[0]
		processSource("wasm", filename)
	},
}
