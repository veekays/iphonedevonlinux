  * Test deployment action as part of the "all" action to make sure all went properly
  * Fix build errors on 64-bit
  * Clean up visuals - better colours and output formatting
  * Support for building older toolchains (2.0?) and future proofing.
  * Check all possible failure points to introduce graceful failure
  * Support for MIG
  * Perhaps this will need to support automation through predefined variables and a "-f" parameter or something.
  * Support for defining some parameters externally (document these):
    * APPLE\_ID
    * APPLE\_PASSWORD
    * FW\_FILE
  * Prevent users running steps in the wrong order. Checks for the presence of the required resources.
  * Implement proper, functional, version specific, class-dump support
  * Port to leopard
  * Fix up 4-spaces instead of tabs
  * Testing
    * Test on 64-bit systems
    * Test on Leopard
    * Test multiversion support (incomplete)