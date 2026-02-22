package cmd

import (
	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(buildCmd)
}

var buildCmd = &cobra.Command{
	Use: "build [file.ss]",
	Short: "Compile to a native executable (via Go)",
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		filename := args[0]
		processSource("build", filename)
	},
}
