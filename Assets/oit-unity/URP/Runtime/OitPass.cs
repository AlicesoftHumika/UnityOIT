using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace OrderIndependentTransparency.URP
{
    internal class OitPass : ScriptableRenderPass
    {
        private readonly IOrderIndependentTransparency orderIndependentTransparency;

        public OitPass()
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
            orderIndependentTransparency = new OitLinkedList("OitRenderURP");
            RenderPipelineManager.beginContextRendering += PreRender;
        }

        private void PreRender(ScriptableRenderContext context, List<Camera> cameras)
        {
            CommandBuffer cmd = CommandBufferPool.Get("Order Independent Transparency Pre Render");
            orderIndependentTransparency.PreRender(cmd);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("Order Independent Transparency");

            Material mat = orderIndependentTransparency.Render(cmd/*, renderingData.cameraData.renderer.cameraColorTargetHandle,renderingData.cameraData.renderer.cameraColorTargetHandle*/);

            // Can only use in URP 13.0+.
            //Blitter.BlitCameraTexture(cmd, renderingData.cameraData.renderer.cameraColorTargetHandle, renderingData.cameraData.renderer.cameraColorTargetHandle, mat, 0);

            // Use in URP 12.0-.
            cmd.Blit(Shader.PropertyToID("_CameraColorAttachmentA"), Shader.PropertyToID("_CameraColorAttachmentA"), mat, 0);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void Cleanup()
        {
            orderIndependentTransparency.Release();
            RenderPipelineManager.beginContextRendering -= PreRender;
        }
    }
}