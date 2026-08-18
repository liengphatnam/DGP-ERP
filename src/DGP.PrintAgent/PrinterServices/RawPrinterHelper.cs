using System.ComponentModel;
using System.Runtime.InteropServices;

namespace DGP.PrintAgent.PrinterServices;

public sealed class RawPrinterHelper
{
    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool StartDocPrinter(IntPtr hPrinter, int level, ref DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    private static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBuf, int dwCount, out int dwWritten);

    public void SendStringToPrinter(string printerName, string rawString)
    {
        var docInfo = new DOCINFOA
        {
            pDocName = "DGP Label",
            pDataType = "RAW"
        };

        if (!OpenPrinter(printerName, out var hPrinter, IntPtr.Zero))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), $"Unable to open printer '{printerName}'.");
        }

        try
        {
            if (!StartDocPrinter(hPrinter, 1, ref docInfo))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), $"Unable to start print job for '{printerName}'.");
            }

            if (!StartPagePrinter(hPrinter))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), $"Unable to start page for '{printerName}'.");
            }

            var buffer = Marshal.StringToCoTaskMemAnsi(rawString);
            try
            {
                var success = WritePrinter(hPrinter, buffer, rawString.Length, out var _);
                if (!success)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), $"Unable to write raw data to printer '{printerName}'.");
                }
            }
            finally
            {
                Marshal.FreeCoTaskMem(buffer);
            }

            EndPagePrinter(hPrinter);
            EndDocPrinter(hPrinter);
        }
        finally
        {
            ClosePrinter(hPrinter);
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    private struct DOCINFOA
    {
        [MarshalAs(UnmanagedType.LPStr)]
        public string pDocName;

        [MarshalAs(UnmanagedType.LPStr)]
        public string pOutputFile;

        [MarshalAs(UnmanagedType.LPStr)]
        public string pDataType;
    }
}
