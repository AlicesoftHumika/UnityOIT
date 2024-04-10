using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthPeelingRenderFeature : ScriptableRendererFeature
{
    public int peelingCount = 8;
    public class DepthPeelingRenderPass : ScriptableRenderPass
    {
        FilteringSettings m_FilteringSettings;
        ProfilingSampler m_ProfilingSampler;
        RenderStateBlock m_RenderStateBlock;
        int peelingCount = 0;

        List<int> colorRTs;
        List<int> depthRTs;

        public DepthPeelingRenderPass(RenderQueueRange renderQueueRange, int peelingCount)
        {
            m_ProfilingSampler = new ProfilingSampler("Depth Peeling");
            m_FilteringSettings = new FilteringSettings(renderQueueRange);
            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            this.peelingCount = peelingCount;

            colorRTs = new List<int>(peelingCount);
            depthRTs = new List<int>(peelingCount);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
        {
            Camera camera = renderingData.cameraData.camera;
            FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.transparent);
            SortingSettings sortingSettings = new SortingSettings(camera);
            sortingSettings.criteria = SortingCriteria.CommonTransparent;
            DrawingSettings drawingSettings = new DrawingSettings(new ShaderTagId("DepthPeelingFirstPass"), sortingSettings)
            {
                enableDynamicBatching = true,
                perObjectData = PerObjectData.ReflectionProbes,
            };
            RenderStateBlock stateBlock = new RenderStateBlock(RenderStateMask.Nothing);

            var cmd = CommandBufferPool.Get("Depth Peeling");
            // Start profilling
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            List<int> colorRTs = new List<int>(peelingCount);
            List<int> depthRTs = new List<int>(peelingCount);

            // Perform depth peeling
            for (var i = 0; i < peelingCount; i++)
            {
                depthRTs.Add(Shader.PropertyToID($"_DepthPeelingDepth{i}"));
                colorRTs.Add(Shader.PropertyToID($"_DepthPeelingColor{i}"));
                cmd.GetTemporaryRT(colorRTs[i], camera.pixelWidth, camera.pixelHeight, 0);
                cmd.GetTemporaryRT(depthRTs[i], camera.pixelWidth, camera.pixelHeight, 32, FilterMode.Point, RenderTextureFormat.RFloat);

                if (i == 0)
                {
                    drawingSettings.SetShaderPassName(0, new ShaderTagId("DepthPeelingFirstPass"));

                    cmd.SetRenderTarget(new RenderTargetIdentifier[] { colorRTs[i], depthRTs[i] }, depthRTs[i]);
                    cmd.ClearRenderTarget(true, true, Color.black);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings, ref stateBlock);
                }
                else
                {
                    cmd.SetGlobalTexture("_MaxDepthTex", depthRTs[i - 1]);
                    drawingSettings.SetShaderPassName(0, new ShaderTagId("DepthPeelingPass"));

                    cmd.SetRenderTarget(new RenderTargetIdentifier[] { colorRTs[i], depthRTs[i] }, depthRTs[i]);
                    cmd.ClearRenderTarget(true, true, Color.black);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings, ref stateBlock);
                }
            }

            cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget, BuiltinRenderTextureType.CameraTarget);
            var mat = new Material(Shader.Find("OITRP/Transparent"));
            for (var i = peelingCount - 1; i >= 0; i--)
            {
                cmd.SetGlobalTexture("_DepthTex", depthRTs[i]);
                cmd.Blit(colorRTs[i], Shader.PropertyToID("_CameraColorAttachmentA"), mat, 4);

                cmd.ReleaseTemporaryRT(depthRTs[i]);
                cmd.ReleaseTemporaryRT(colorRTs[i]);
            }
            //cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget, BuiltinRenderTextureType.CameraTarget);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    DepthPeelingRenderPass m_pass;

    public override void Create()
    {
        m_pass = new DepthPeelingRenderPass(RenderQueueRange.transparent, peelingCount);
        m_pass.renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref UnityEngine.Rendering.Universal.RenderingData renderingData)
    {
        renderer.EnqueuePass(m_pass);
    }
}
