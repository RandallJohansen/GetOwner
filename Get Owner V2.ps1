


cls  # for cut paste running



# inline C# code


$cmd = {    # this block will be running as a job


Add-Type -TypeDefinition @"

// running as a job, think this is needed for output via "log" method
using System.Linq;                         
//using System.Diagnostics;  // declaring below
using System.Threading;


using System;
using System.Runtime.InteropServices;
using System.Diagnostics;                   // To use Process class, need declare System.Diagnostics namespace
using System.Security.Principal;            // WindowsIdentity
using System.ComponentModel;                // GetOwner
//using System.Management;                    // WMI
//using Microsoft.Management.Infrastructure;  // CIM
//using System.IO;                            // StreamWriter - used for stdout, file, prob tcp too 


namespace System.Diagnostics
{


        ////////////////////////////     CLASS     ////////////////////////////

     //   public class ManagementObjectSearcher : System.ComponentModel.Component {}    // WMI


        public class GetOwner : Component
        {


                ////////////////////////////     JOB OUTPUT BUFFER     ////////////////////////////

                public static string APPLICATION_OUTPUT = "";

                public static void Log(object toLog)
                {
                    if (toLog != null)
                        APPLICATION_OUTPUT += toLog.ToString() + Environment.NewLine;
                }


                ////////////////////////////     VAR's     ////////////////////////////
                

                public IntPtr myhandle { get; set; }



                ////////////////////////////     DLL's     ////////////////////////////
                
                [DllImport("advapi32.dll", SetLastError = true)]
                private static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

                [DllImport("kernel32.dll", SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                private static extern bool CloseHandle(IntPtr hObject);



                ////////////////////////////     METHOD's     ////////////////////////////



                // Since WMI is not always a fast way of retrieving information, so using P/invoke

                // return value is null when unsuccessful. In order to get the names of processes running under the SYSTEM user, you need to execute this code as administrator.

                // Note: WindowsIdentity is disposable, so you'd want to use a using statement when you new up the WindowsIdentity. Like this: using var wi = new WindowsIdentity(processHandle);



              
      //          public IntPtr myhandle { get; set; }
                
             // handle is being gotten by PS, not sure how to glob app name in c#, it's a to-do 
             // --> is name what is returned when blocking on new process creation? 
             //   Process[] processes = Process.GetProcessesByName("MyApp");
             // System.Diagnostics.Process.GetProcesses()



              //  private static string GetProcessUser(Process process)
                public string GetProcessUser()
                {

//                    Log("MethodD executing");
                    //Console.WriteLine("MethodD executing");      // does not work as PS job


                    IntPtr TokenHandle = IntPtr.Zero;

                    try
                    {
//                            Log("getting TokenHandle using handle below:");
//                            Log( myhandle );

              //          OpenProcessToken(process.Handle, 8, out processHandle);
                        OpenProcessToken(myhandle, 8, out TokenHandle);

//                            Log("have TokenHandle");
//                            Log( TokenHandle );
                            int error = Marshal.GetLastWin32Error();
//                            Log( error );

                        WindowsIdentity wi = new WindowsIdentity(TokenHandle);

//                            Log("have WindowsIdentity");

                        string user = wi.Name;

//                            Log("MethodD done");


                        return   user.Contains(@"\") ? user.Substring(user.IndexOf(@"\") + 1) : user;


                    } catch (Exception e) {

                        Log(e);  

                        Log("TokenHandle");
                        Log( TokenHandle );

                        var w32ex = e as Win32Exception;

                        if(w32ex == null) {
                            w32ex = e.InnerException as Win32Exception;
                            Log(w32ex);
                        }    

                        if(w32ex != null) {
                            int code =  w32ex.ErrorCode;
                            Log(code.ToString()) ;
                        }    

                        return null; // APPLICATION_OUTPUT;  // "unknown error" ;  // null; 


                    } finally {

                        if (TokenHandle != IntPtr.Zero)
                        {
                            CloseHandle(TokenHandle);
                        }
                    }

                } // GetProcessUser()


        } // class





        public class MainProgram : Component
        {
        
               
                public static uint DesiredAccess = 4096;    // PROCESS_QUERY_LIMITED_INFORMATION (numeric value 4096 or 0x1000)
                public static bool InheritHandle = false;

                [DllImport("kernel32.dll")]
                private static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
                
                [DllImport("kernel32.dll", SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                private static extern bool CloseHandle(IntPtr hObject);


                public string run() // static void Main() //  * no return value allowed * // 
                {

                        GetOwner object1 = new GetOwner();

                        Process[] processlist = Process.GetProcesses();

                        foreach (Process theprocess in processlist)
                        {

                               uint pid = Convert.ToUInt32(theprocess.Id);
                        
                               IntPtr temphandle = OpenProcess(DesiredAccess, InheritHandle, pid);

                               object1.myhandle = temphandle;

                               string Owner = object1.GetProcessUser( );  // uses myhandle

                            // req v6  string Msg = $"Process: {theprocess.ProcessName} ID: {theprocess.Id} Owner: {Owner}";
                               string Msg = String.Format( "Process: {0} ID: {1} Owner: {2}", theprocess.ProcessName, theprocess.Id, Owner );

                               Console.WriteLine(Msg);

                               GetOwner.Log(Msg);

                               bool rc = CloseHandle( temphandle );

                        } // foreach

                        return GetOwner.APPLICATION_OUTPUT;  ;// 

                } // Main()



        } // class

}  // namespace

"@


 ########################     GET OWNER     ########################
 
 $b = New-Object System.Diagnostics.MainProgram
 
 $b.run()


} # $cmd


    ########################     MAIN{}     ########################

    $j = Start-Job -ScriptBlock $cmd

    do 
    {
        Receive-Job -Job $j

    } while ( $j.State -eq "Running" )



Get-Job
Get-Job | Stop-Job
Get-Job | Remove-Job
Get-Job


# console only version ( not ISE editor or visual Studio ), remove notifyicon code to use this

# $t=(get-date).AddSeconds(30) ; while ( (Get-Date ) -lt $t ) { sleep -Seconds 1 }
Write-Host -NoNewLine 'Press any key to exit...';
# $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
while ( -not [Console]::KeyAvailable) { sleep -milliseconds 300 }

