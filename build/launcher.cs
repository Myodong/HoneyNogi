using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        try
        {
            // 데이터 폴더: %LOCALAPPDATA%\MabinogiAuto (스크립트/설정/로그가 여기 저장됨)
            string dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MabinogiAuto");
            Directory.CreateDirectory(dir);
            Directory.CreateDirectory(Path.Combine(dir, "Log"));

            // 스크립트는 항상 최신으로 교체(EXE 업데이트 반영), 설정은 사용자 것 유지
            Extract("gui.ps1", Path.Combine(dir, "mabinogi_gui.ps1"), true);
            Extract("run_once.ps1", Path.Combine(dir, "mabinogi_run_once.ps1"), true);
            Extract("redirect.ps1", Path.Combine(dir, "rdp_redirect_console.ps1"), true);
            Extract("config.json", Path.Combine(dir, "config.json"), false);
            // 내장 최신 config 를 비교 기준용으로 항상 추출: GUI 가 시작할 때 사용자 config 의
            // 버전(coordsVersion)이 이보다 낮으면 사용자 설정만 옮겨 담아 자동 이전합니다
            Extract("config.json", Path.Combine(dir, "config.default.json"), true);

            var psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \""
                + Path.Combine(dir, "mabinogi_gui.ps1") + "\"";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            MessageBox.Show("실행 준비 중 오류가 발생했습니다:\n" + ex.Message,
                "마비노기 자동화", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    static void Extract(string resourceName, string destPath, bool overwrite)
    {
        if (!overwrite && File.Exists(destPath)) return;
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
        {
            if (s == null) throw new Exception("내장 리소스를 찾지 못했습니다: " + resourceName);
            using (FileStream f = File.Create(destPath))
            {
                s.CopyTo(f);
            }
        }
    }
}
